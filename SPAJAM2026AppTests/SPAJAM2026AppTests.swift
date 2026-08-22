//
//  SPAJAM2026AppTests.swift
//  SPAJAM2026AppTests
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

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
