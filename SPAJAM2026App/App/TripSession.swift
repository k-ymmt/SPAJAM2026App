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
        case planning      // プラン確認中
        case traveling     // 旅行中
        case finished      // 全ミッション終了
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
    private let activityController = TripActivityController()

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

    func startTrip() {
        phase = .traveling
        currentIndex = 0
        if let mission = currentMission {
            activityController.start(plan: plan, mission: mission)
        }
    }

    func endTrip() {
        phase = .finished
        activityController.end()
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
