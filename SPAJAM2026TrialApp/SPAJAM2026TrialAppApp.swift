//
//  SPAJAM2026TrialAppApp.swift
//  SPAJAM2026TrialApp
//
//  Created by Kazuki Yamamoto on 2026/08/17.
//

import SwiftUI

@main
struct SPAJAM2026TrialAppApp: App {
    @State private var receiver = WatchHeartRateReceiver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(receiver)
        }
    }
}
