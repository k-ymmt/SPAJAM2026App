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
