//
//  WatchSessionRelay.swift
//  SPAJAM2026App
//
//  Thin WatchConnectivity wrapper for the phone side. It lives off the main
//  actor because `WCSessionDelegate` callbacks arrive on a background queue;
//  decoded values are handed to the caller through `@Sendable` callbacks.
//

import Foundation
import WatchConnectivity

nonisolated struct WatchStatus: Sendable, Equatable {
    var isSupported = false
    var isPaired = false
    var isWatchAppInstalled = false
    var isReachable = false

    var label: String {
        if !isSupported { return "この端末では Apple Watch を利用できません" }
        if !isPaired { return "Apple Watch がペアリングされていません" }
        if !isWatchAppInstalled { return "Watch アプリがインストールされていません" }
        return isReachable ? "Watch アプリと接続中" : "Watch アプリを起動すると接続されます"
    }

    var canSendCommands: Bool { isSupported && isPaired && isWatchAppInstalled && isReachable }
}

nonisolated final class WatchSessionRelay: NSObject, WCSessionDelegate {
    var onMessage: (@Sendable (HeartRateMessage) -> Void)?
    var onStatusChange: (@Sendable (WatchStatus) -> Void)?

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    func activate() {
        guard let session else {
            onStatusChange?(WatchStatus())
            return
        }
        session.delegate = self
        session.activate()
        publishStatus()
    }

    var status: WatchStatus {
        guard let session else { return WatchStatus() }
        return WatchStatus(
            isSupported: true,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )
    }

    /// Sends a message when the watch app is reachable; returns `false` otherwise.
    @discardableResult
    func send(_ message: HeartRateMessage) -> Bool {
        guard let session, session.activationState == .activated, session.isReachable else {
            return false
        }
        session.sendMessage(message.dictionary, replyHandler: nil)
        return true
    }

    private func publishStatus() {
        onStatusChange?(status)
    }

    private func handle(_ dictionary: [String: Any]) {
        guard let message = HeartRateMessage(dictionary: dictionary) else { return }
        onMessage?(message)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: (any Error)?) {
        publishStatus()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        publishStatus()
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        publishStatus()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        publishStatus()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }
}
