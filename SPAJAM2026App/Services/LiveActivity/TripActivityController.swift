//
//  TripActivityController.swift
//  SPAJAM2026App
//
//  旅行中の Live Activity の開始・更新・終了。
//  表示は山本さん実装の TABI MISSION Live Activity(MissionActivityAttributes /
//  SPAJAM2026AppWidgets の MissionLiveActivity)を使用する。
//

import ActivityKit
import Foundation

@MainActor
final class TripActivityController {
    private var activity: Activity<MissionActivityAttributes>?

    func start(plan: TravelPlan, mission: Mission) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }
        let attributes = MissionActivityAttributes(brandName: "TABI MISSION", iconSymbol: "safari.fill")
        let state = contentState(mission: mission, total: plan.missions.count, achievedCount: 0, distanceMeters: nil, bpm: nil)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(mission: Mission, total: Int, achievedCount: Int, distanceMeters: Double?, bpm: Double?) {
        guard let activity else { return }
        let state = contentState(
            mission: mission,
            total: total,
            achievedCount: achievedCount,
            distanceMeters: distanceMeters,
            bpm: bpm
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    private func contentState(
        mission: Mission,
        total: Int,
        achievedCount: Int,
        distanceMeters: Double?,
        bpm: Double?
    ) -> MissionActivityAttributes.ContentState {
        .init(
            missionNumber: mission.order,
            missionTotal: total,
            missionText: mission.title,
            landmarkName: "目的地",
            distanceMeters: distanceMeters,
            heartRate: bpm,
            indicator: MissionIndicator(segmentCount: total, completedCount: achievedCount),
            updatedAt: Date()
        )
    }
}
