//
//  WatchHeartRateReceiver.swift
//  SPAJAM2026App
//
//  Apple Watch から WatchConnectivity 経由で届く心拍を受け取る。
//

import Foundation
import WatchConnectivity
import os

nonisolated private let logger = Logger(subsystem: "app.kymmt.SPAJAM2026App", category: "Connectivity")

@MainActor
@Observable
final class WatchHeartRateReceiver {
    private(set) var latest: HeartRateUpdate?
    private(set) var isWatchReachable = false
    private(set) var isWatchAppInstalled = false

    private let session: WCSession?
    private var delegate: SessionDelegate?

    init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        guard let session else { return }

        let delegate = SessionDelegate(
            onUpdate: { [weak self] update in
                guard let self else { return }
                Task { @MainActor in self.apply(update) }
            },
            onSessionChange: { [weak self] reachable, installed in
                guard let self else { return }
                Task { @MainActor in
                    self.isWatchReachable = reachable
                    self.isWatchAppInstalled = installed
                }
            }
        )
        self.delegate = delegate
        session.delegate = delegate
        session.activate()

        // 起動前に Watch が送っていた最後の値があれば復元する。
        if let update = HeartRateUpdate(payload: session.receivedApplicationContext) {
            latest = update
        }
    }

    private func apply(_ update: HeartRateUpdate) {
        // sendMessage と applicationContext の両方で同じ値が届くことがあるので、古い値では上書きしない。
        if let latest, update.measuredAt < latest.measuredAt { return }
        latest = update
    }
}

private nonisolated final class SessionDelegate: NSObject, WCSessionDelegate {
    private let onUpdate: @Sendable (HeartRateUpdate) -> Void
    private let onSessionChange: @Sendable (_ reachable: Bool, _ installed: Bool) -> Void

    init(
        onUpdate: @escaping @Sendable (HeartRateUpdate) -> Void,
        onSessionChange: @escaping @Sendable (Bool, Bool) -> Void
    ) {
        self.onUpdate = onUpdate
        self.onSessionChange = onSessionChange
    }

    private func notifySessionChange(_ session: WCSession) {
        onSessionChange(session.isReachable, session.isWatchAppInstalled)
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            logger.error("WCSession の有効化に失敗: \(error.localizedDescription, privacy: .public)")
        }
        notifySessionChange(session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Watch を切り替えた場合などに呼ばれる。再度有効化しておく。
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        notifySessionChange(session)
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        notifySessionChange(session)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let update = HeartRateUpdate(payload: message) else {
            logger.debug("不明なメッセージを受信: \(message.keys.joined(separator: ","), privacy: .public)")
            return
        }
        onUpdate(update)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let update = HeartRateUpdate(payload: applicationContext) else { return }
        onUpdate(update)
    }
}
