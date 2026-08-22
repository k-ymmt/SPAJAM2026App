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
    private(set) var currentIndex = 0
    private(set) var records: [MissionRecord] = []
    private(set) var heartRateSamples: [HeartRateSample] = []
    private(set) var isJudging = false
    private(set) var lastFailReason: String?

    /// Mock 判定に切り替えるスイッチ(電波なしデモ用)。キー未設定時は自動で Mock
    var useMockJudge: Bool

    let heartRateReceiver = WatchHeartRateReceiver()
    let shield = ShieldService()
    private let activityController = TripActivityController()

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

    var currentMission: Mission? {
        guard phase == .traveling, plan.missions.indices.contains(currentIndex) else { return nil }
        return plan.missions[currentIndex]
    }

    var totalPoints: Int { records.reduce(0) { $0 + $1.points } }

    var isAchieved: (Mission) -> Bool {
        { [records] mission in records.contains { $0.missionId == mission.id } }
    }

    // MARK: - フロー

    /// プラン確認 → おやすみ設定へ
    func proceedToRestrictionSetup() {
        phase = .restrictionSetup
    }

    func startTrip() {
        phase = .traveling
        currentIndex = 0
        tripStartedAt = Date()
        becameActiveAt = Date()
        shield.start()
        if let mission = currentMission {
            activityController.start(plan: plan, mission: mission)
        }
    }

    func endTrip() {
        noteScenePhase(active: false)
        tripEndedAt = Date()
        phase = .finished
        shield.stop()
        activityController.end()
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
    }

    // MARK: - 判定

    private var engine: JudgmentEngine {
        let judge: any PhotoAIJudging =
            if useMockJudge { MockPhotoAIJudge() }
            else { GeminiPhotoAIJudge.fromSecrets() ?? MockPhotoAIJudge() }
        return JudgmentEngine(photoJudge: judge)
    }

    /// 撮影した写真で現在ミッションを判定する。達成なら true
    func judgeCurrentMission(image: UIImage?, location: CLLocation?, answerText: String? = nil) async -> Bool {
        guard let mission = currentMission else { return false }
        isJudging = true
        lastFailReason = nil
        defer { isJudging = false }

        let bpm = heartRateReceiver.latest?.beatsPerMinute
        recordHeartRateIfAvailable()

        let input = JudgeInput(
            image: image,
            location: location,
            currentBPM: bpm,
            baselineBPM: baselineBPM,
            answerText: answerText
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
            advance()
            return true
        case .failed(let reason):
            lastFailReason = reason
            return false
        }
    }

    private func advance() {
        if currentIndex + 1 < plan.missions.count {
            currentIndex += 1
            if let mission = currentMission {
                activityController.update(
                    mission: mission,
                    total: plan.missions.count,
                    distanceText: nil,
                    bpm: heartRateReceiver.latest?.beatsPerMinute.map(Int.init)
                )
            }
        } else {
            endTrip()
        }
    }

    // MARK: - 心拍

    private func recordHeartRateIfAvailable() {
        if let update = heartRateReceiver.latest, let bpm = update.beatsPerMinute {
            heartRateSamples.append(HeartRateSample(date: update.measuredAt, bpm: bpm))
        }
    }

    /// 安静時基準: 記録の最初の数サンプルの平均(なければ nil)
    private var baselineBPM: Double? {
        let head = heartRateSamples.prefix(5)
        guard !head.isEmpty else { return nil }
        return head.reduce(0) { $0 + $1.bpm } / Double(head.count)
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
