//
//  HeartRateTests.swift
//  SPAJAM2026AppTests
//
//  Unit tests for the framework-independent parts of the heart rate feature.
//

import Foundation
import Testing
@testable import SPAJAM2026App

struct HeartRateMessageTests {

    @Test func heartRateRoundTrips() throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let message = HeartRateMessage.heartRate(beatsPerMinute: 72.5, timestamp: date)
        let decoded = try #require(HeartRateMessage(dictionary: message.dictionary))
        #expect(decoded == message)
    }

    @Test func streamingStateRoundTrips() throws {
        for isActive in [true, false] {
            let message = HeartRateMessage.streamingState(isActive: isActive)
            let decoded = try #require(HeartRateMessage(dictionary: message.dictionary))
            #expect(decoded == message)
        }
    }

    @Test func commandRoundTrips() throws {
        for command in [HeartRateMessage.Command.start, .stop] {
            let message = HeartRateMessage.command(command)
            let decoded = try #require(HeartRateMessage(dictionary: message.dictionary))
            #expect(decoded == message)
        }
    }

    @Test func dictionaryOnlyContainsPropertyListTypes() {
        let message = HeartRateMessage.heartRate(beatsPerMinute: 60, timestamp: .now)
        #expect(PropertyListSerialization.propertyList(message.dictionary, isValidFor: .binary))
    }

    @Test func malformedDictionariesAreRejected() {
        #expect(HeartRateMessage(dictionary: [:]) == nil)
        #expect(HeartRateMessage(dictionary: ["type": "heartRate"]) == nil)
        #expect(HeartRateMessage(dictionary: ["type": "heartRate", "bpm": "fast", "timestamp": 0.0]) == nil)
        #expect(HeartRateMessage(dictionary: ["type": "command", "command": "jump"]) == nil)
        #expect(HeartRateMessage(dictionary: ["type": "nope"]) == nil)
    }
}

struct HeartRateHistoryTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func sample(_ offset: TimeInterval, bpm: Double = 70, source: HeartRateSample.Source = .watch) -> HeartRateSample {
        HeartRateSample(timestamp: now.addingTimeInterval(offset), beatsPerMinute: bpm, source: source)
    }

    @Test func insertKeepsChronologicalOrder() {
        var history = HeartRateHistory(window: 120)
        let r1 = history.insert(sample(-10, bpm: 80), now: now)
        #expect(r1)
        let r2 = history.insert(sample(-30, bpm: 70), now: now)
        #expect(r2)
        let r3 = history.insert(sample(-20, bpm: 75), now: now)
        #expect(r3)
        #expect(history.samples.map(\.beatsPerMinute) == [70, 75, 80])
        #expect(history.latest?.beatsPerMinute == 80)
    }

    @Test func duplicateTimestampsAreIgnored() {
        var history = HeartRateHistory(window: 120)
        let r4 = history.insert(sample(-5, bpm: 70), now: now)
        #expect(r4)
        let r5 = history.insert(sample(-5, bpm: 99, source: .health), now: now)
        #expect(!r5)
        #expect(history.samples.count == 1)
        #expect(history.latest?.beatsPerMinute == 70)
    }

    @Test func samplesOutsideWindowAreDroppedOnInsertAndTrim() {
        var history = HeartRateHistory(window: 60)
        let r6 = history.insert(sample(-61), now: now)
        #expect(!r6)
        let r7 = history.insert(sample(-59), now: now)
        #expect(r7)
        let r8 = history.insert(sample(-1), now: now)
        #expect(r8)
        history.trim(now: now.addingTimeInterval(30))
        #expect(history.samples.count == 1)
        #expect(history.latest?.timestamp == now.addingTimeInterval(-1))
    }

    @Test func invalidValuesAreRejected() {
        var history = HeartRateHistory()
        let r9 = history.insert(sample(0, bpm: 0), now: now)
        #expect(!r9)
        let r10 = history.insert(sample(0, bpm: -5), now: now)
        #expect(!r10)
        let r11 = history.insert(sample(0, bpm: .nan), now: now)
        #expect(!r11)
        #expect(history.isEmpty)
    }

    @Test func statisticsReflectSamples() {
        var history = HeartRateHistory()
        #expect(history.average == nil)
        history.insert(sample(-3, bpm: 60), now: now)
        history.insert(sample(-2, bpm: 80), now: now)
        history.insert(sample(-1, bpm: 100), now: now)
        #expect(history.minimum == 60)
        #expect(history.maximum == 100)
        #expect(history.average == 80)
    }
}

struct HeartRateFormatTests {

    @Test func bpmIsRoundedToWholeNumber() {
        #expect(HeartRateFormat.bpm(72.4) == "72")
        #expect(HeartRateFormat.bpm(72.6) == "73")
    }

    @Test func beatIntervalMatchesRate() {
        #expect(HeartRateFormat.beatInterval(for: 60) == 1)
        #expect(HeartRateFormat.beatInterval(for: 120) == 0.5)
        #expect(HeartRateFormat.beatInterval(for: 0) == 1)
    }
}

struct WatchStatusTests {

    @Test func commandsRequireReachableInstalledWatch() {
        #expect(!WatchStatus().canSendCommands)
        let ready = WatchStatus(isSupported: true, isPaired: true, isWatchAppInstalled: true, isReachable: true)
        #expect(ready.canSendCommands)
        var unreachable = ready
        unreachable.isReachable = false
        #expect(!unreachable.canSendCommands)
        #expect(!unreachable.label.isEmpty)
    }
}
