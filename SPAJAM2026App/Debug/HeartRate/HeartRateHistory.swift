//
//  HeartRateHistory.swift
//  SPAJAM2026App
//
//  A time-windowed, de-duplicated, chronologically ordered buffer of readings.
//  Pure value type so it can be unit tested without HealthKit or a watch.
//

import Foundation

nonisolated struct HeartRateHistory: Sendable, Equatable {
    /// How far back (in seconds) samples are retained.
    let window: TimeInterval
    private(set) var samples: [HeartRateReading] = []

    init(window: TimeInterval = 120) {
        self.window = window
    }

    var latest: HeartRateReading? { samples.last }
    var isEmpty: Bool { samples.isEmpty }

    var minimum: Double? { samples.map(\.beatsPerMinute).min() }
    var maximum: Double? { samples.map(\.beatsPerMinute).max() }

    var average: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.beatsPerMinute).reduce(0, +) / Double(samples.count)
    }

    /// Inserts a sample keeping chronological order, dropping exact timestamp
    /// duplicates and anything older than `window` seconds before `now`.
    /// Returns `true` if the sample was added.
    @discardableResult
    mutating func insert(_ sample: HeartRateReading, now: Date = .now) -> Bool {
        guard sample.beatsPerMinute.isFinite, sample.beatsPerMinute > 0 else { return false }
        if sample.timestamp < now.addingTimeInterval(-window) {
            trim(now: now)
            return false
        }
        if samples.contains(where: { $0.timestamp == sample.timestamp }) {
            return false
        }
        let index = samples.firstIndex { $0.timestamp > sample.timestamp } ?? samples.endIndex
        samples.insert(sample, at: index)
        trim(now: now)
        return true
    }

    mutating func trim(now: Date = .now) {
        let cutoff = now.addingTimeInterval(-window)
        samples.removeAll { $0.timestamp < cutoff }
    }

    mutating func removeAll() {
        samples.removeAll()
    }
}
