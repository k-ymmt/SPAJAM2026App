//
//  TripActivityController.swift
//  SPAJAM2026App
//
//  旅行中の Live Activity(次のミッションだけをロック画面に出す)の開始・更新・終了。
//

import ActivityKit
import Foundation

@MainActor
final class TripActivityController {
    private var activity: Activity<TripActivityAttributes>?

    func start(plan: TravelPlan, mission: Mission) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TripActivityAttributes(planTitle: plan.title)
        let state = contentState(mission: mission, total: plan.missions.count, distanceText: nil, bpm: nil)
        activity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: nil)
        )
    }

    /// キル後の復元: OS 側に残っている Live Activity があれば再接続し、なければ新規に開始する
    func resume(plan: TravelPlan, mission: Mission) {
        if let existing = Activity<TripActivityAttributes>.activities.first {
            activity = existing
            update(mission: mission, total: plan.missions.count, distanceText: nil, bpm: nil)
        } else {
            start(plan: plan, mission: mission)
        }
    }

    func update(mission: Mission, total: Int, distanceText: String?, bpm: Int?) {
        guard let activity else { return }
        let state = contentState(mission: mission, total: total, distanceText: distanceText, bpm: bpm)
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        self.activity = nil
    }

    private func contentState(mission: Mission, total: Int, distanceText: String?, bpm: Int?) -> TripActivityAttributes.ContentState {
        .init(
            missionTitle: mission.title,
            missionOrder: mission.order,
            missionTotal: total,
            distanceText: distanceText,
            bpm: bpm
        )
    }
}
