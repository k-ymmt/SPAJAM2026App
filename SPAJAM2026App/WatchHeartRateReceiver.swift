//
//  WatchHeartRateReceiver.swift
//  SPAJAM2026App
//
//  Apple Watch から届く心拍を旅行フロー向けの `HeartRateUpdate` として公開する。
//
//  `WCSession` のデリゲートはアプリ内で 1 つしか持てないため、実際の受信は
//  アプリ起動時に有効化される `HeartRateFeed` に集約し、ここではその値を読み替えるだけにする。
//  ミッション同期(iPhone → Watch)の送信はデリゲート所有を必要としないため、ここから直接行う。
//

import Foundation
import WatchConnectivity

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

    // MARK: - iPhone → Watch 送信(ミッション同期・触覚)

    /// いまのミッション状態を Watch へ送る(W1 画面用)。
    /// reachable なら即時 sendMessage、加えて applicationContext にも残す(Watch 側の後起動対策)。
    func sendMissionState(_ state: MissionState) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, let payload = try? state.payload() else { return }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
        try? session.updateApplicationContext(payload)
    }

    /// 触覚フィードバックのトリガー(達成・接近・心拍上昇・メンバー達成)を Watch へ送る。
    func sendEvent(_ event: WatchEvent) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(event.payload, replyHandler: nil)
    }

    func sendEvent(_ kind: WatchEventKind) {
        sendEvent(WatchEvent(kind: kind))
    }
}
