//
//  SPAJAM2026AppTests.swift
//  SPAJAM2026AppTests
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

import DeviceActivity
import FamilyControls
import Foundation
import Testing
@testable import SPAJAM2026App

@MainActor
struct SuggestionEntryTests {

    @Test func refreshedKeepsContentButRenewsIdentity() throws {
        let original = try #require(SampleSuggestions.all.first)
        let copy = original.refreshed()

        #expect(copy.id != original.id)
        #expect(copy.title == original.title)
        #expect(copy.dateInterval == original.dateInterval)
        #expect(copy.items.map(\.headline) == original.items.map(\.headline))
        #expect(copy.items.map(\.kind) == original.items.map(\.kind))
        #expect(zip(copy.items, original.items).allSatisfy { $0.id != $1.id })
        #expect(copy.pickedAt >= original.pickedAt)
    }

    @Test func sampleSuggestionsAreDisplayable() {
        #expect(!SampleSuggestions.all.isEmpty)
        for entry in SampleSuggestions.all {
            #expect(!entry.title.isEmpty)
            #expect(!entry.items.isEmpty)
            #expect(entry.items.allSatisfy { !$0.headline.isEmpty })
        }
    }

    @Test func sampleSuggestionIdentifiersAreUnique() {
        let ids = SampleSuggestions.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func everyKindHasSymbolAndLabel() {
        for kind in SuggestionItemKind.allCases {
            #expect(!kind.symbolName.isEmpty)
            #expect(!kind.label.isEmpty)
        }
    }
}

@MainActor
struct SuggestionFormatTests {

    @Test func sameDayIntervalIsRenderedAsRange() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let text = SuggestionFormat.interval(DateInterval(start: start, duration: 3600))
        #expect(text.contains("–"))
    }

    @Test func zeroLengthIntervalDropsTheRange() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let text = SuggestionFormat.interval(DateInterval(start: start, duration: 0))
        #expect(!text.contains("–"))
    }

    @Test func multiDayIntervalMentionsBothEnds() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let interval = DateInterval(start: start, duration: 3 * 24 * 3600)
        let text = SuggestionFormat.interval(interval)
        #expect(text.contains(SuggestionFormat.date(start)))
        #expect(text.contains(SuggestionFormat.date(interval.end)))
    }

    @Test func durationIsFormatted() {
        #expect(!SuggestionFormat.duration(5400).isEmpty)
    }
}

@MainActor
struct ScreenTimeScheduleBuilderTests {

    @Test func defaultScheduleCoversWholeDay() {
        let builder = ScreenTimeScheduleBuilder()
        #expect(builder.durationMinutes == 23 * 60 + 59)
        #expect(builder.isValid)
        #expect(builder.warningComponents == nil)
        #expect(builder.startComponents == DateComponents(hour: 0, minute: 0))
        #expect(builder.endComponents == DateComponents(hour: 23, minute: 59))
    }

    @Test func overnightScheduleWrapsAroundMidnight() {
        let builder = ScreenTimeScheduleBuilder(startHour: 22, startMinute: 0, endHour: 1, endMinute: 30)
        #expect(builder.durationMinutes == 210)
    }

    @Test func shiftingWrapsAroundMidnight() {
        var builder = ScreenTimeScheduleBuilder(startHour: 0, startMinute: 5, endHour: 23, endMinute: 50)
        builder.shiftStart(by: -15)
        #expect(builder.startHour == 23 && builder.startMinute == 50)
        builder.shiftEnd(by: 15)
        #expect(builder.endHour == 0 && builder.endMinute == 5)
    }

    @Test func shortScheduleIsInvalid() {
        let builder = ScreenTimeScheduleBuilder(startHour: 10, startMinute: 0, endHour: 10, endMinute: 10)
        #expect(!builder.isValid)
    }

    @Test func warningMinutesBecomeComponents() {
        let builder = ScreenTimeScheduleBuilder(warningMinutes: 5)
        #expect(builder.warningComponents == DateComponents(minute: 5))
        let schedule = builder.makeSchedule()
        #expect(schedule.warningTime == DateComponents(minute: 5))
        #expect(schedule.repeats)
    }

    @Test func fromNowUsesGivenClock() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = Date(timeIntervalSince1970: 1_750_000_000) // 2025-06-15 15:06:40 UTC
        let builder = ScreenTimeScheduleBuilder.fromNow(minutes: 30, calendar: calendar, now: now)
        #expect(builder.startHour == 15 && builder.startMinute == 6)
        #expect(builder.endHour == 15 && builder.endMinute == 36)
        #expect(!builder.repeats)
        #expect(builder.durationMinutes == 30)
    }
}

struct ScreenTimeFormatTests {

    @Test func summaryListsAllCounts() {
        #expect(ScreenTimeFormat.summary(applications: 1, categories: 2, webDomains: 3) == "アプリ 1 / カテゴリ 2 / Web 3")
    }

    @Test func timeIsZeroPadded() {
        #expect(ScreenTimeFormat.time(hour: 7, minute: 5) == "07:05")
    }

    @Test func authorizationLabelsAreDistinct() {
        let labels = [ScreenTimeFormat.label(for: .notDetermined), ScreenTimeFormat.label(for: .denied), ScreenTimeFormat.label(for: .approved)]
        #expect(Set(labels).count == 3)
    }
}

@MainActor
struct ScreenTimeSelectionStoreTests {

    @Test func roundTripsSelection() throws {
        let suite = "ScreenTimeSelectionStoreTests"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let previous = ScreenTimeSelectionStore.defaults
        ScreenTimeSelectionStore.defaults = defaults
        defer { ScreenTimeSelectionStore.defaults = previous }

        #expect(ScreenTimeSelectionStore.load() == nil)
        ScreenTimeSelectionStore.save(FamilyActivitySelection(includeEntireCategory: true))
        let loaded = try #require(ScreenTimeSelectionStore.load())
        #expect(loaded.includeEntireCategory)
        #expect(loaded.applicationTokens.isEmpty)
        ScreenTimeSelectionStore.clear()
        #expect(ScreenTimeSelectionStore.load() == nil)
    }
}
