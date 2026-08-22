//
//  AdvanceTrialActivityIntent.swift
//  SPAJAM2026App
//
//  An interactive button inside the Live Activity. `LiveActivityIntent` runs in the
//  app's process, so the type must be compiled into both the app and the extension.
//

import ActivityKit
import AppIntents

struct AdvanceTrialActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Advance trial activity"
    static let description = IntentDescription("Advances the progress of the trial Live Activity by 10%.")

    @Parameter(title: "Activity ID")
    var activityID: String

    init() {}

    init(activityID: String) {
        self.activityID = activityID
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<TrialActivityAttributes>.activities
            .first(where: { $0.id == activityID }) else {
            return .result()
        }
        var state = activity.content.state
        state.progress = min(1, state.progress + 0.1)
        state.statusText = state.progress >= 1 ? "完了(ボタン)" : "ボタンで進行中 \(Int(state.progress * 100))%"
        await activity.update(ActivityContent(state: state, staleDate: nil))
        return .result()
    }
}
