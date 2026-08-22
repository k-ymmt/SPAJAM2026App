//
//  TripSession.swift
//  SPAJAM2026App
//
//  旅行 1 回分の進行状態。プラン・現在ミッション・達成ログ・心拍を持ち、判定を仲介する。
//

import CoreLocation
import Foundation
import UIKit

@MainActor
@Observable
final class TripSession {
    enum Phase {
        case planning         // プラン確認中
        case restrictionSetup // おやすみ設定(シールド選択)
        case traveling        // 旅行中
        case finished         // 全ミッション終了
    }

    let plan: TravelPlan
    private(set) var phase: Phase = .planning
    /// いま挑戦中のミッション(順不同で選択可能)
    private(set) var currentMissionId: String?
    private(set) var records: [MissionRecord] = []
    private(set) var heartRateSamples: [HeartRateSample] = []
    private(set) var isJudging = false
    private(set) var lastFailReason: String?

    /// Mock 判定に切り替えるスイッチ(電波なしデモ用)。キー未設定時は自動で Mock
    var useMockJudge: Bool

    let heartRateReceiver = WatchHeartRateReceiver()
    let shield = ShieldService()
    let locationProvider = LocationProvider()
    private let activityController = TripActivityController()
    /// 接近振動を送ったミッション(1 ミッション 1 回だけ)
    private var nearNotified: Set<String> = []
    /// Live Activity の定期更新タスク
    private var activityRefreshTask: Task<Void, Never>?

    // 「みない時間」計測: 旅行中にこのアプリを見ていた時間を積算する
    private var tripStartedAt: Date?
    private var tripEndedAt: Date?
    private var foregroundSeconds: TimeInterval = 0
    private var becameActiveAt: Date?

    init(plan: TravelPlan = .bundledDemoPlan()) {
        self.plan = plan
        // Secrets にキーが無ければ Mock
        self.useMockJudge = GeminiPhotoAIJudge.fromSecrets() == nil
    }

    // MARK: - 永続化(キル後の復元)

    /// 保存済みスナップショットから復元する。phase が traveling ならシールド・Live Activity も再接続する
    init(snapshot: TripSessionSnapshot) {
        self.plan = snapshot.plan
        self.useMockJudge = snapshot.useMockJudge
        self.phase = switch snapshot.phase {
        case .planning: .planning
        case .restrictionSetup: .restrictionSetup
        case .traveling: .traveling
        case .finished: .finished
        }
        self.currentMissionId = snapshot.currentMissionId
        self.records = snapshot.records
        self.heartRateSamples = snapshot.heartRateSamples
        self.tripStartedAt = snapshot.tripStartedAt
        self.tripEndedAt = snapshot.tripEndedAt
        self.restrictionAdjustments = snapshot.restrictionAdjustments
        // キル前に前面だった時間は、最後に保存した時刻までを前面扱いで確定する
        var foreground = snapshot.foregroundSeconds
        if let since = snapshot.becameActiveAt {
            foreground += max(0, snapshot.savedAt.timeIntervalSince(since))
        }
        self.foregroundSeconds = foreground
        self.becameActiveAt = nil

        shield.restore(selectionData: snapshot.shieldSelectionData)
        if phase == .traveling {
            shield.start()
            if let mission = currentMission {
                activityController.resume(plan: plan, mission: mission)
            }
            beginTravelingSideEffects()
        }
    }

    /// 保存されていれば復元、なければ nil
    static func restore() -> TripSession? {
        guard let snapshot = TripSessionStore.load() else { return nil }
        return TripSession(snapshot: snapshot)
    }

    private var snapshotPhase: TripSessionSnapshot.Phase {
        switch phase {
        case .planning: .planning
        case .restrictionSetup: .restrictionSetup
        case .traveling: .traveling
        case .finished: .finished
        }
    }

    var snapshot: TripSessionSnapshot {
        TripSessionSnapshot(
            plan: plan,
            phase: snapshotPhase,
            currentMissionId: currentMissionId,
            records: records,
            heartRateSamples: heartRateSamples,
            useMockJudge: useMockJudge,
            tripStartedAt: tripStartedAt,
            tripEndedAt: tripEndedAt,
            foregroundSeconds: foregroundSeconds,
            becameActiveAt: becameActiveAt,
            restrictionAdjustments: restrictionAdjustments,
            shieldSelectionData: shield.selectionData,
            savedAt: Date()
        )
    }

    /// 現在の状態を保存する。状態が変わるたびに呼ぶ
    func persist() {
        TripSessionStore.save(snapshot)
    }

    /// セッションを破棄する(リザルトから最初に戻るとき)。保存データも消す
    func discard() {
        TripSessionStore.clear()
    }

    var currentMission: Mission? {
        guard phase == .traveling else { return nil }
        return plan.missions.first { $0.id == currentMissionId }
    }

    /// ミッションを選んで挑戦対象を切り替える(順不同・達成済みは選べない)
    func selectMission(_ mission: Mission) {
        guard phase == .traveling, !records.contains(where: { $0.missionId == mission.id }) else { return }
        currentMissionId = mission.id
        lastFailReason = nil
        updateActivity()
        sendMissionStateToWatch()
        persist()
    }

    var totalPoints: Int { records.reduce(0) { $0 + $1.points } }

    var isAchieved: (Mission) -> Bool {
        { [records] mission in records.contains { $0.missionId == mission.id } }
    }

    // MARK: - フロー

    /// プラン確認 → おやすみ設定へ
    func proceedToRestrictionSetup() {
        phase = .restrictionSetup
        persist()
    }

    func startTrip() {
        phase = .traveling
        currentMissionId = plan.missions.first?.id
        tripStartedAt = Date()
        becameActiveAt = Date()
        shield.start()
        if let mission = currentMission {
            activityController.start(plan: plan, mission: mission)
        }
        beginTravelingSideEffects()
        persist()
    }

    /// 旅行中に必要なバックグラウンド処理(位置監視・Watch 送信・LA 定期更新)。開始時と復元時に呼ぶ
    private func beginTravelingSideEffects() {
        // 位置監視(接近振動 + LA の距離表示)
        locationProvider.onUpdate = { [weak self] location in
            self?.handleLocation(location)
        }
        locationProvider.start()
        // 通知許可(接近・心拍上昇・メンバー達成をロック画面にも出す)
        Task { await TripNotifier.shared.requestAuthorization() }
        // Watch へ現在ミッションを送信 + LA を 15 秒ごとに更新(bpm・距離)
        sendMissionStateToWatch()
        activityRefreshTask?.cancel()
        activityRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.recordHeartRateIfAvailable()
                self?.checkHeartSpike()
                self?.updateActivity()
            }
        }
    }

    func endTrip() {
        noteScenePhase(active: false)
        tripEndedAt = Date()
        phase = .finished
        shield.stop()
        activityController.end()
        activityRefreshTask?.cancel()
        activityRefreshTask = nil
        locationProvider.stop()
        persist()
    }

    // MARK: - 位置更新(接近振動・LA 距離)

    private func handleLocation(_ location: CLLocation) {
        guard phase == .traveling, let mission = currentMission,
              let target = mission.judgment.location else { return }
        let distance = location.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
        // 半径の 2 倍 or 200m 以内に入ったら Watch に接近振動(ミッションごとに 1 回)
        let nearThreshold = max(200, target.radiusMeters * 2)
        if distance <= nearThreshold, mission.hapticOnNear == true, !nearNotified.contains(mission.id) {
            nearNotified.insert(mission.id)
            let place = target.name ?? "目的地"
            heartRateReceiver.sendEvent(WatchEvent(kind: .near, text: "\(place)がもうすぐ!"))
            TripNotifier.shared.post(
                kind: "near",
                title: "🗺️ \(place)がもうすぐ!",
                body: "ミッション「\(mission.title)」のチャンス"
            )
        }
    }

    // MARK: - 心拍上昇(写真チャンス)

    /// 直近サンプルが移動平均を大きく上回ったら「心が動いた」として Watch 触覚+通知
    private var lastSpikeAt: Date?

    private func checkHeartSpike() {
        guard phase == .traveling,
              let bpm = heartRateReceiver.latest?.beatsPerMinute else { return }
        // 直近を除いた過去サンプルの平均を基準にする(最低 5 サンプル)
        let history = heartRateSamples.dropLast().suffix(20).map(\.bpm)
        guard history.count >= 5 else { return }
        let average = history.reduce(0, +) / Double(history.count)
        guard bpm - average >= 15 else { return }
        // 3 分に 1 回まで
        if let last = lastSpikeAt, Date().timeIntervalSince(last) < 180 { return }
        lastSpikeAt = Date()
        heartRateReceiver.sendEvent(WatchEvent(kind: .heartSpike, text: "心が動いた! 写真を撮ろう"))
        TripNotifier.shared.post(
            kind: "heartSpike",
            title: "❤️ 心が動いた瞬間!",
            body: "心拍が \(Int(bpm.rounded())) bpm に上がったよ。写真を撮って残そう"
        )
    }

    // MARK: - メンバー達成(同期レイヤーから呼ぶ)

    /// 自分以外のメンバーの達成を受け取ったときに呼ぶ(Watch 触覚+通知)
    func noteMemberAchieved(memberName: String, missionTitle: String) {
        guard phase == .traveling else { return }
        heartRateReceiver.sendEvent(WatchEvent(kind: .memberAchieved, text: "\(memberName)が達成!"))
        TripNotifier.shared.post(
            kind: "memberAchieved",
            title: "🎉 \(memberName)がミッション達成!",
            body: "「\(missionTitle)」をクリアしたよ"
        )
    }

    /// LA 用の目的地までの距離(GPS 条件のあるミッションのみ)
    private var distanceMeters: Double? {
        guard let mission = currentMission,
              let target = mission.judgment.location,
              let location = locationProvider.current else { return nil }
        return location.distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))
    }

    // MARK: - Watch 連携

    private func sendMissionStateToWatch() {
        guard let mission = currentMission else { return }
        heartRateReceiver.sendMissionState(
            MissionState(
                planTitle: plan.title,
                missionTitle: mission.title,
                order: mission.order,
                total: plan.missions.count,
                achievedCount: records.count
            )
        )
    }

    /// アプリの前面/背面切り替えを記録(旅行中のみ積算)
    func noteScenePhase(active: Bool) {
        guard phase == .traveling else { return }
        if active {
            becameActiveAt = Date()
        } else if let since = becameActiveAt {
            foregroundSeconds += Date().timeIntervalSince(since)
            becameActiveAt = nil
        }
        persist()
    }

    // MARK: - スコア 3 要素(正式名称)

    /// QUEST SCORE: ミッションをどれだけ達成したか
    var questScore: Int { totalPoints }

    /// HEART SCORE: どれだけ心が動いたか(心拍数の上下 = ワクワク・感動)
    var heartScore: Int { focusScore }

    /// OFFLINE SCORE: どれだけスマホを見ずに過ごしたか
    /// = 見なかった分数 + 制限数ボーナス − 旅行中の制限調整ペナルティ
    var offlineScore: Int {
        max(0, notLookingMinutes + shieldBonus - adjustPenalty)
    }

    var totalScore: Int { questScore + heartScore + offlineScore }

    /// 旅行時間のうちスマホ(このアプリ)を見ていなかった分数
    private var notLookingMinutes: Int {
        guard let start = tripStartedAt else { return 0 }
        let end = tripEndedAt ?? Date()
        var active = foregroundSeconds
        if let since = becameActiveAt { active += end.timeIntervalSince(since) }
        let notLooking = max(0, end.timeIntervalSince(start) - active)
        return Int(notLooking / 60)
    }

    /// 制限数ボーナス: シールドしたアプリ/カテゴリ 1 つにつき +2pt(上限 10pt)
    private var shieldBonus: Int {
        min(10, shield.selectionCount * 2)
    }

    // MARK: - 旅行中の制限調整(ペナルティつき)

    /// 旅行中に制限を調整した回数。1 回につき OFFLINE SCORE -5pt
    private(set) var restrictionAdjustments = 0

    var adjustPenalty: Int { restrictionAdjustments * 5 }

    /// 旅行中に制限設定を変更したときに呼ぶ。新しい選択でシールドを再適用し、ペナルティを加算
    func applyShieldAdjustment() {
        guard phase == .traveling else { return }
        restrictionAdjustments += 1
        shield.stop()
        shield.start()
        persist()
    }

    // MARK: - 判定

    private var engine: JudgmentEngine {
        let judge: any PhotoAIJudging =
            if useMockJudge { MockPhotoAIJudge() }
            else { GeminiPhotoAIJudge.fromSecrets() ?? MockPhotoAIJudge() }
        return JudgmentEngine(photoJudge: judge)
    }

    /// 撮影した写真で現在ミッションを判定する。達成なら true
    func judgeCurrentMission(image: UIImage?, location: CLLocation?) async -> Bool {
        guard let mission = currentMission else { return false }
        isJudging = true
        lastFailReason = nil
        defer { isJudging = false }

        let bpm = heartRateReceiver.latest?.beatsPerMinute
        recordHeartRateIfAvailable()

        let input = JudgeInput(
            image: image,
            location: location
        )

        switch await engine.judge(mission: mission, input: input) {
        case .achieved(let comment):
            let record = MissionRecord(
                missionId: mission.id,
                achievedAt: Date(),
                photoFileName: saveImage(image, missionId: mission.id),
                bpmAtAchieve: bpm.map(Int.init),
                points: mission.points,
                aiComment: comment
            )
            records.append(record)
            heartRateReceiver.sendEvent(.achieved)
            advance()
            persist()
            return true
        case .failed(let reason):
            lastFailReason = reason
            return false
        }
    }

    private func advance() {
        let achieved = Set(records.map(\.missionId))
        // 順序どおりの「次の未達成」を優先しつつ、無ければ先頭から探す(順不同対応)
        let remaining = plan.missions.filter { !achieved.contains($0.id) }
        if let next = remaining.first {
            currentMissionId = next.id
            updateActivity()
            sendMissionStateToWatch()
        } else {
            endTrip()
        }
    }

    private func updateActivity() {
        guard let mission = currentMission else { return }
        activityController.update(
            mission: mission,
            total: plan.missions.count,
            achievedCount: records.count,
            distanceMeters: distanceMeters,
            bpm: heartRateReceiver.latest?.beatsPerMinute
        )
    }

    // MARK: - 心拍

    private func recordHeartRateIfAvailable() {
        if let update = heartRateReceiver.latest, let bpm = update.beatsPerMinute {
            heartRateSamples.append(HeartRateSample(date: update.measuredAt, bpm: bpm))
        }
    }

    /// 集中スコア: 心拍の移動平均からの平均偏差(サンプルが無ければ 0)
    var focusScore: Int {
        let bpms = heartRateSamples.map(\.bpm)
        guard bpms.count >= 3 else { return 0 }
        let mean = bpms.reduce(0, +) / Double(bpms.count)
        let deviation = bpms.reduce(0) { $0 + abs($1 - mean) } / Double(bpms.count)
        return Int(deviation * 10)
    }

    // MARK: - 写真保存

    private func saveImage(_ image: UIImage?, missionId: String) -> String? {
        guard let data = image?.jpegData(compressionQuality: 0.7) else { return nil }
        let name = "mission-\(missionId).jpg"
        let url = URL.documentsDirectory.appending(path: name)
        try? data.write(to: url)
        return name
    }

    func photo(for record: MissionRecord) -> UIImage? {
        guard let name = record.photoFileName else { return nil }
        return UIImage(contentsOfFile: URL.documentsDirectory.appending(path: name).path)
    }
}
