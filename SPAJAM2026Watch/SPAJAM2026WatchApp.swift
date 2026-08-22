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
        _sender = State(initialValue: sender)
        _workoutManager = State(initialValue: HeartRateWorkoutManager(sender: sender))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(sender)
                .environment(workoutManager)
        }
    }
}
