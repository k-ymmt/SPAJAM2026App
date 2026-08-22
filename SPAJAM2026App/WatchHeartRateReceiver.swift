//
//  WatchHeartRateReceiver.swift
//  SPAJAM2026App
//
//  Apple Watch から届く心拍を旅行フロー向けの `HeartRateUpdate` として公開する。
//
//  `WCSession` のデリゲートはアプリ内で 1 つしか持てないため、実際の受信は
//  アプリ起動時に有効化される `HeartRateFeed` に集約し、ここではその値を読み替えるだけにする。
//

import Foundation

@MainActor
@Observable
final class WatchHeartRateReceiver {
    private let feed = HeartRateFeed.shared

    init() {
        feed.activateSession()
    }

    /// 直近の心拍。Watch が計測中で値が未着の間は bpm が nil の更新を返す。
    var latest: HeartRateUpdate? {
        if let reading = feed.latest {
            return HeartRateUpdate(
                beatsPerMinute: reading.beatsPerMinute,
                measuredAt: reading.timestamp,
                isMeasuring: feed.isWatchStreaming
            )
        }
        return feed.isWatchStreaming ? HeartRateUpdate(beatsPerMinute: nil, measuredAt: .now, isMeasuring: true) : nil
    }

    var isWatchReachable: Bool { feed.watchStatus.isReachable }
    var isWatchAppInstalled: Bool { feed.watchStatus.isWatchAppInstalled }
}
