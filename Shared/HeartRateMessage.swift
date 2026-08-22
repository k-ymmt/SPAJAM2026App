//
//  HeartRateMessage.swift
//  Shared between the iOS app and the watchOS app.
//
//  Framework-independent types that travel over WatchConnectivity. They are
//  encoded as plain property-list dictionaries because that is all
//  `WCSession` accepts.
//

import Foundation

/// One heart rate reading.
nonisolated struct HeartRateReading: Sendable, Hashable, Identifiable {
    enum Source: String, Sendable, Hashable {
        /// Streamed live from the watch app's workout session.
        case watch
        /// Read from the local HealthKit store (synced by the system).
        case health
    }

    let timestamp: Date
    let beatsPerMinute: Double
    let source: Source

    var id: Date { timestamp }

    init(timestamp: Date, beatsPerMinute: Double, source: Source) {
        self.timestamp = timestamp
        self.beatsPerMinute = beatsPerMinute
        self.source = source
    }
}

/// Messages exchanged between the phone and the watch.
nonisolated enum HeartRateMessage: Sendable, Equatable {
    /// Watch → phone: a new reading.
    case heartRate(beatsPerMinute: Double, timestamp: Date)
    /// Watch → phone: whether the workout session is currently running.
    case streamingState(isActive: Bool)
    /// Phone → watch: ask the watch app to start or stop streaming.
    case command(Command)

    enum Command: String, Sendable {
        case start
        case stop
    }

    private enum Key {
        static let type = "type"
        static let bpm = "bpm"
        static let timestamp = "timestamp"
        static let isActive = "isActive"
        static let command = "command"
    }

    private enum Kind: String {
        case heartRate
        case streamingState
        case command
    }

    var dictionary: [String: Any] {
        switch self {
        case let .heartRate(bpm, timestamp):
            [
                Key.type: Kind.heartRate.rawValue,
                Key.bpm: bpm,
                Key.timestamp: timestamp.timeIntervalSince1970,
            ]
        case let .streamingState(isActive):
            [
                Key.type: Kind.streamingState.rawValue,
                Key.isActive: isActive,
            ]
        case let .command(command):
            [
                Key.type: Kind.command.rawValue,
                Key.command: command.rawValue,
            ]
        }
    }

    init?(dictionary: [String: Any]) {
        guard let raw = dictionary[Key.type] as? String, let kind = Kind(rawValue: raw) else {
            return nil
        }
        switch kind {
        case .heartRate:
            guard let bpm = dictionary[Key.bpm] as? Double,
                  let seconds = dictionary[Key.timestamp] as? TimeInterval
            else { return nil }
            self = .heartRate(beatsPerMinute: bpm, timestamp: Date(timeIntervalSince1970: seconds))
        case .streamingState:
            guard let isActive = dictionary[Key.isActive] as? Bool else { return nil }
            self = .streamingState(isActive: isActive)
        case .command:
            guard let raw = dictionary[Key.command] as? String,
                  let command = Command(rawValue: raw)
            else { return nil }
            self = .command(command)
        }
    }
}

// MARK: - Formatting

nonisolated enum HeartRateFormat {
    /// "72" — whole beats per minute, no unit.
    static func bpm(_ value: Double) -> String {
        value.rounded().formatted(.number.precision(.fractionLength(0)))
    }

    /// Seconds between beats for the given rate; used to drive the pulse animation.
    static func beatInterval(for beatsPerMinute: Double) -> TimeInterval {
        guard beatsPerMinute > 0 else { return 1 }
        return 60 / beatsPerMinute
    }
}
