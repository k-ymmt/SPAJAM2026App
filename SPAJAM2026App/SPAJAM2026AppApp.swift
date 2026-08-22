//
//  SPAJAM2026AppApp.swift
//  SPAJAM2026App
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

import SwiftUI

@main
struct SPAJAM2026AppApp: App {
    init() {
        // Firebase(匿名認証 + Firestore)。GoogleService-Info.plist が無ければスキップ
        FirebaseBootstrap.configureIfPossible()
        // Activate WatchConnectivity at launch so the watch can wake this app in the
        // background with heart rate messages, and re-attach to a running mission activity.
        HeartRateFeed.shared.activateSession()
        _ = MissionLiveActivityModel.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
