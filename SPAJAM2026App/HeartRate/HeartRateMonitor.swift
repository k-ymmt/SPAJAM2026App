//
//  HeartRateMonitor.swift
//  SPAJAM2026App
//
//  Main-actor model behind the real-time heart rate screen. Merges readings
//  streamed from the watch app with readings observed in HealthKit.
//

import Foundation
import Observation

@Observable
final class HeartRateMonitor {
    private(set) var history = HeartRateHistory(window: 120)
    private(set) var watchStatus = WatchStatus()
    private(set) var isWatchStreaming = false
    private(set) var healthAuthorization: HealthKitHeartRateSource.Authorization = .notDetermined
    private(set) var lastCommandError: String?

    var latest: HeartRateSample? { history.latest }

    /// Seconds since the latest reading, refreshed by the view's timer.
    func age(at now: Date = .now) -> TimeInterval? {
        latest.map { now.timeIntervalSince($0.timestamp) }
    }

    private let relay = WatchSessionRelay()
    private let healthSource = HealthKitHeartRateSource()
    private var isRunning = false

    func start() async {
        guard !isRunning else { return }
        isRunning = true

        relay.onMessage = { [weak self] message in
            Task { @MainActor in self?.receive(message) }
        }
        relay.onStatusChange = { [weak self] status in
            Task { @MainActor in self?.watchStatus = status }
        }
        relay.activate()

        healthSource.onSample = { [weak self] sample in
            Task { @MainActor in self?.append(sample) }
        }
        healthAuthorization = await healthSource.requestAuthorization()
        if healthAuthorization == .authorized {
            healthSource.start(since: .now.addingTimeInterval(-history.window))
        }
    }

    func stop() {
        healthSource.stop()
        isRunning = false
    }

    func clear() {
        history.removeAll()
    }

    func sendCommand(_ command: HeartRateMessage.Command) {
        lastCommandError = nil
        if !relay.send(.command(command)) {
            lastCommandError = "Watch アプリに接続できません。Watch 側でアプリを開いてください。"
        }
    }

    /// Drops stale samples; call periodically from the view.
    func tick(now: Date = .now) {
        history.trim(now: now)
    }

    private func receive(_ message: HeartRateMessage) {
        switch message {
        case let .heartRate(bpm, timestamp):
            append(HeartRateSample(timestamp: timestamp, beatsPerMinute: bpm, source: .watch))
            isWatchStreaming = true
        case let .streamingState(isActive):
            isWatchStreaming = isActive
        case .command:
            break
        }
    }

    private func append(_ sample: HeartRateSample) {
        history.insert(sample)
    }
}
