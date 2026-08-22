//
//  HeartRateFeed.swift
//  SPAJAM2026App
//
//  App-wide heart rate source. Owns the single `WCSession` delegate and the
//  HealthKit observer so that any screen (and the mission Live Activity) can
//  consume readings — including while the app is in the background:
//
//  * The watch app runs a workout session and calls `WCSession.sendMessage`
//    for every reading. iOS launches/wakes the counterpart app in the
//    background to deliver those messages as long as the session was
//    activated at launch, which is why `activateSession()` is called from
//    the `App` initializer.
//  * As a fallback, HealthKit background delivery wakes the app when heart
//    rate samples synced from the watch land in the local store.
//

import Foundation
import Observation

@MainActor
@Observable
final class HeartRateFeed {
    static let shared = HeartRateFeed()

    private(set) var latest: HeartRateSample?
    private(set) var watchStatus = WatchStatus()
    private(set) var isWatchStreaming = false
    private(set) var healthAuthorization: HealthKitHeartRateSource.Authorization = .notDetermined
    private(set) var lastCommandError: String?

    private let relay = WatchSessionRelay()
    private let healthSource = HealthKitHeartRateSource()
    private var isSessionActivated = false
    private var isHealthRunning = false
    private var subscribers: [UUID: @MainActor (HeartRateSample) -> Void] = [:]

    private init() {}

    /// Activates WatchConnectivity. Safe to call repeatedly; call once at app launch.
    func activateSession() {
        guard !isSessionActivated else { return }
        isSessionActivated = true
        relay.onMessage = { [weak self] message in
            Task { @MainActor in self?.receive(message) }
        }
        relay.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.watchStatus = status }
        }
        relay.activate()
        healthSource.onSample = { [weak self] sample in
            Task { @MainActor in self?.publish(sample) }
        }
    }

    /// Requests HealthKit access and starts observing (with background delivery).
    func startHealthKit(since: Date = .now.addingTimeInterval(-120)) async {
        activateSession()
        guard !isHealthRunning else { return }
        healthAuthorization = await healthSource.requestAuthorization()
        guard healthAuthorization == .authorized else { return }
        isHealthRunning = true
        healthSource.start(since: since)
        await healthSource.enableBackgroundDelivery()
    }

    func stopHealthKit() {
        healthSource.stop()
        isHealthRunning = false
    }

    func sendCommand(_ command: HeartRateMessage.Command) {
        activateSession()
        lastCommandError = nil
        if !relay.send(.command(command)) {
            lastCommandError = "Watch アプリに接続できません。Watch 側でアプリを開いてください。"
        }
    }

    @discardableResult
    func subscribe(_ handler: @escaping @MainActor (HeartRateSample) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = handler
        return id
    }

    func unsubscribe(_ id: UUID) {
        subscribers[id] = nil
    }

    private func receive(_ message: HeartRateMessage) {
        switch message {
        case let .heartRate(bpm, timestamp):
            isWatchStreaming = true
            publish(HeartRateSample(timestamp: timestamp, beatsPerMinute: bpm, source: .watch))
        case let .streamingState(isActive):
            isWatchStreaming = isActive
        case .command:
            break
        }
    }

    private func publish(_ sample: HeartRateSample) {
        guard sample.beatsPerMinute.isFinite, sample.beatsPerMinute > 0 else { return }
        if let latest, latest.timestamp > sample.timestamp { return }
        latest = sample
        for handler in subscribers.values { handler(sample) }
    }
}
