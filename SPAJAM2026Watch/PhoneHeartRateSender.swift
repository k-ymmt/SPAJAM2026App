//
//  PhoneHeartRateSender.swift
//  SPAJAM2026Watch
//
//  WatchConnectivity で iPhone に心拍を送る。
//

import Foundation
import WatchConnectivity
import os

nonisolated private let logger = Logger(subsystem: "app.kymmt.SPAJAM2026App.watchkitapp", category: "Connectivity")

@MainActor
@Observable
final class PhoneHeartRateSender {
    private(set) var isPhoneReachable = false

    private let session: WCSession?
    private var delegate: SessionDelegate?

    init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        guard let session else { return }

        let delegate = SessionDelegate { [weak self] reachable in
            guard let self else { return }
            Task { @MainActor in self.isPhoneReachable = reachable }
        }
        self.delegate = delegate
        session.delegate = delegate
        session.activate()
    }

    /// 最新の心拍を iPhone に送る。
    ///
    /// - iPhone アプリが前面にいる (reachable) 間は `sendMessage` で即時配信する。
    /// - それとは別に `updateApplicationContext` も常に更新しておき、iPhone 側が後から起動しても
    ///   最後の値を受け取れるようにする (古い未送信分はシステムが自動で置き換える)。
    func send(_ update: HeartRateUpdate) {
        guard let session, session.activationState == .activated else { return }

        let payload: [String: Any]
        do {
            payload = try update.payload()
        } catch {
            logger.error("payload のエンコードに失敗: \(error.localizedDescription, privacy: .public)")
            return
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                logger.debug("sendMessage 失敗: \(error.localizedDescription, privacy: .public)")
            }
        }

        do {
            try session.updateApplicationContext(payload)
        } catch {
            logger.debug("updateApplicationContext 失敗: \(error.localizedDescription, privacy: .public)")
        }
    }
}

private nonisolated final class SessionDelegate: NSObject, WCSessionDelegate {
    private let reachabilityChanged: @Sendable (Bool) -> Void

    init(reachabilityChanged: @escaping @Sendable (Bool) -> Void) {
        self.reachabilityChanged = reachabilityChanged
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        if let error {
            logger.error("WCSession の有効化に失敗: \(error.localizedDescription, privacy: .public)")
        }
        reachabilityChanged(session.isReachable)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        reachabilityChanged(session.isReachable)
    }
}
