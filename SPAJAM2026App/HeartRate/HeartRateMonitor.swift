//
//  HeartRateMonitor.swift
//  SPAJAM2026App
//
//  Main-actor model behind the real-time heart rate screen. Keeps a short
//  history of the readings published by `HeartRateFeed`.
//

import Foundation
import Observation

@MainActor
@Observable
final class HeartRateMonitor {
    private(set) var history = HeartRateHistory(window: 120)

    var watchStatus: WatchStatus { feed.watchStatus }
    var isWatchStreaming: Bool { feed.isWatchStreaming }
    var healthAuthorization: HealthKitHeartRateSource.Authorization { feed.healthAuthorization }
    var lastCommandError: String? { feed.lastCommandError }

    var latest: HeartRateSample? { history.latest }

    /// Seconds since the latest reading, refreshed by the view's timer.
    func age(at now: Date = .now) -> TimeInterval? {
        latest.map { now.timeIntervalSince($0.timestamp) }
    }

    private let feed = HeartRateFeed.shared
    private var subscription: UUID?

    func start() async {
        guard subscription == nil else { return }
        subscription = feed.subscribe { [weak self] sample in
            self?.append(sample)
        }
        if let latest = feed.latest { append(latest) }
        await feed.startHealthKit(since: .now.addingTimeInterval(-history.window))
    }

    func stop() {
        if let subscription { feed.unsubscribe(subscription) }
        subscription = nil
    }

    func clear() {
        history.removeAll()
    }

    func sendCommand(_ command: HeartRateMessage.Command) {
        feed.sendCommand(command)
    }

    /// Drops stale samples; call periodically from the view.
    func tick(now: Date = .now) {
        history.trim(now: now)
    }

    private func append(_ sample: HeartRateSample) {
        history.insert(sample)
    }
}
