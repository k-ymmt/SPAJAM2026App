//
//  PhoneHeartRateSender.swift
//  SPAJAM2026Watch
//
//  WatchConnectivity で iPhone に心拍を送り、iPhone からの開始/停止コマンドを受け取る。
//

import Foundation
import WatchConnectivity
import WatchKit
import os

nonisolated private let logger = Logger(subsystem: "app.kymmt.SPAJAM2026App.watchkitapp", category: "Connectivity")

@MainActor
@Observable
final class PhoneHeartRateSender {
    private(set) var isPhoneReachable = false
    /// iPhone から届いた「いまのミッション」(W1 画面用)
    private(set) var missionState: MissionState?
    /// 直近の達成イベント(達成演出のトリガー。UI が見たら nil に戻す)
    var achievedPulse = false
    /// 直近の通知イベント文言(接近・心拍上昇・メンバー達成のバナー。UI が見たら nil に戻す)
    var eventBanner: String?

    /// iPhone から計測の開始/停止を要求されたときに呼ばれる。
    var onCommand: (@MainActor (HeartRateMessage.Command) -> Void)?

    private let session: WCSession?
    private var delegate: SessionDelegate?

    init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        guard let session else { return }

        let delegate = SessionDelegate(
            reachabilityChanged: { [weak self] reachable in
                guard let self else { return }
                Task { @MainActor in self.isPhoneReachable = reachable }
            },
            commandReceived: { [weak self] command in
                guard let self else { return }
                Task { @MainActor in self.onCommand?(command) }
            },
            onMissionState: { [weak self] state in
                guard let self else { return }
                Task { @MainActor in self.missionState = state }
            },
            onEvent: { [weak self] event in
                guard let self else { return }
                Task { @MainActor in self.handleEvent(event) }
            }
        )
        self.delegate = delegate
        session.delegate = delegate
        session.activate()

        // Watch 側が後から起動しても最後のミッション状態を復元できるようにする
        if let state = MissionState(payload: session.receivedApplicationContext) {
            missionState = state
        }
    }

    /// 触覚フィードバック: 達成は成功、接近・メンバー達成は通知、心拍上昇は上方向ハプティクス
    private func handleEvent(_ event: WatchEvent) {
        switch event.kind {
        case .achieved:
            WKInterfaceDevice.current().play(.success)
            achievedPulse = true
        case .near:
            WKInterfaceDevice.current().play(.notification)
            eventBanner = event.text ?? "目的地がもうすぐ!"
        case .heartSpike:
            WKInterfaceDevice.current().play(.directionUp)
            eventBanner = event.text ?? "心が動いた! 写真を撮ろう"
        case .memberAchieved:
            WKInterfaceDevice.current().play(.notification)
            eventBanner = event.text ?? "メンバーが達成!"
        }
    }

    /// 最新の心拍を iPhone に送る。
    ///
    /// - iPhone アプリが前面にいる (reachable) 間は `sendMessage` で即時配信する。
    /// - それとは別に `updateApplicationContext` も常に更新しておき、iPhone 側が後から起動しても
    ///   最後の値を受け取れるようにする (古い未送信分はシステムが自動で置き換える)。
    ///
    /// ペイロードには `HeartRateUpdate`(旅行フロー用)と `HeartRateMessage`(心拍フィード用)の
    /// 両形式を同居させ、iPhone 側のどちらの受信経路でも解釈できるようにする。
    func send(_ update: HeartRateUpdate) {
        guard let session, session.activationState == .activated else { return }

        var payload: [String: Any]
        do {
            payload = try update.payload()
        } catch {
            logger.error("payload のエンコードに失敗: \(error.localizedDescription, privacy: .public)")
            return
        }
        payload.merge(Self.feedMessage(for: update).dictionary) { current, _ in current }

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

    private static func feedMessage(for update: HeartRateUpdate) -> HeartRateMessage {
        if update.isMeasuring, let bpm = update.beatsPerMinute {
            return .heartRate(beatsPerMinute: bpm, timestamp: update.measuredAt)
        }
        return .streamingState(isActive: update.isMeasuring)
    }
}

private nonisolated final class SessionDelegate: NSObject, WCSessionDelegate {
    private let reachabilityChanged: @Sendable (Bool) -> Void
    private let commandReceived: @Sendable (HeartRateMessage.Command) -> Void
    private let onMissionState: @Sendable (MissionState) -> Void
    private let onEvent: @Sendable (WatchEvent) -> Void

    init(
        reachabilityChanged: @escaping @Sendable (Bool) -> Void,
        commandReceived: @escaping @Sendable (HeartRateMessage.Command) -> Void,
        onMissionState: @escaping @Sendable (MissionState) -> Void,
        onEvent: @escaping @Sendable (WatchEvent) -> Void
    ) {
        self.reachabilityChanged = reachabilityChanged
        self.commandReceived = commandReceived
        self.onMissionState = onMissionState
        self.onEvent = onEvent
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let state = MissionState(payload: applicationContext) { onMissionState(state) }
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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if case let .command(command)? = HeartRateMessage(dictionary: message) {
            commandReceived(command)
        }
        if let state = MissionState(payload: message) { onMissionState(state) }
        if let event = WatchEvent(payload: message) { onEvent(event) }
    }
}
