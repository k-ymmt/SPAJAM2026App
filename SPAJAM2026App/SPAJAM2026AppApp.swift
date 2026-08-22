//
//  SPAJAM2026AppApp.swift
//  SPAJAM2026App
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

import SwiftUI

@main
struct SPAJAM2026AppApp: App {
    /// XCTest / Swift Testing のホストとして起動されたか。
    /// ユニットテストはこのアプリをホストに実行されるため、起動時の同期 XPC(CoreLocation・ActivityKit・
    /// WatchConnectivity・Firebase)をスキップして、起動ウォッチドッグ(30 秒, 0x8BADF00D)による kill と
    /// Live Activity 生成などの副作用を避ける。
    static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }

    init() {
        guard !Self.isRunningTests else {
            NSLog("[App] テスト実行中のため起動時の初期化(Firebase / WatchConnectivity / Live Activity)をスキップします")
            return
        }
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
