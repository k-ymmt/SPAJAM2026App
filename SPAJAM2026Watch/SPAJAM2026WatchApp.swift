//
//  SPAJAM2026WatchApp.swift
//  SPAJAM2026Watch
//

import SwiftUI

@main
struct SPAJAM2026WatchApp: App {
    @State private var sender: PhoneHeartRateSender
    @State private var workoutManager: HeartRateWorkoutManager

    init() {
        let sender = PhoneHeartRateSender()
        let workoutManager = HeartRateWorkoutManager(sender: sender)
        // iPhone 側(心拍フィード画面)からの開始/停止要求に応える。
        sender.onCommand = { command in
            switch command {
            case .start: Task { await workoutManager.start() }
            case .stop: workoutManager.stop()
            }
        }
        _sender = State(initialValue: sender)
        _workoutManager = State(initialValue: workoutManager)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sender)
                .environment(workoutManager)
        }
    }
}
