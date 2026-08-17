//
//  SPAJAM2026TrialWatchAppApp.swift
//  SPAJAM2026TrialWatchApp Watch App
//
//  Created by Kazuki Yamamoto on 2026/08/17.
//

import SwiftUI

@main
struct SPAJAM2026TrialWatchApp_Watch_AppApp: App {
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
