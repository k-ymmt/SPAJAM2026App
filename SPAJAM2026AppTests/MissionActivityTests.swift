//
//  MissionActivityTests.swift
//  SPAJAM2026AppTests
//

import CoreLocation
import Foundation
import Testing
@testable import SPAJAM2026App

struct MissionIndicatorTests {
    @Test func segmentsFollowCompletedAndActive() {
        let indicator = MissionIndicator(segmentCount: 5, completedCount: 1, highlightsActive: true)
        #expect(indicator.segments == [.completed, .active, .pending, .pending, .pending])
    }

    @Test func activeCanBeDisabled() {
        let indicator = MissionIndicator(segmentCount: 3, completedCount: 1, highlightsActive: false)
        #expect(indicator.segments == [.completed, .pending, .pending])
    }

    @Test func valuesAreClamped() {
        let tooMany = MissionIndicator(segmentCount: 4, completedCount: 9)
        #expect(tooMany.completedCount == 4)
        #expect(tooMany.segments == [.completed, .completed, .completed, .completed])
        let negative = MissionIndicator(segmentCount: 0, completedCount: -1)
        #expect(negative.segmentCount == 1)
        #expect(negative.completedCount == 0)
    }
}

struct MissionDistanceFormatTests {
    @Test func metersBelowOneKilometer() {
        #expect(MissionDistanceFormat.label(landmark: "雷門", meters: 120.4) == "雷門から 120m")
        #expect(MissionDistanceFormat.distance(999.4) == "999m")
    }

    @Test func kilometers() {
        #expect(MissionDistanceFormat.distance(1234) == "1.2km")
        #expect(MissionDistanceFormat.distance(12_345) == "12km")
    }

    @Test func missingOrInvalid() {
        #expect(MissionDistanceFormat.distance(nil) == "--")
        #expect(MissionDistanceFormat.distance(-1) == "--")
        #expect(MissionDistanceFormat.distance(.nan) == "--")
    }
}

struct MissionContentStateTests {
    @Test func derivedTexts() {
        let state = MissionActivityAttributes.ContentState(
            missionNumber: 2, missionTotal: 5, missionText: "x", landmarkName: "雷門",
            distanceMeters: 120, heartRate: 82.4, indicator: MissionIndicator(), updatedAt: .now
        )
        #expect(state.missionCounterText == "ミッション 2/5")
        #expect(state.distanceText == "雷門から 120m")
        #expect(state.heartRateText == "82 bpm")
        var noData = state
        noData.heartRate = nil
        noData.distanceMeters = nil
        #expect(noData.heartRateText == "-- bpm")
        #expect(noData.distanceText == "雷門から --")
    }

    @Test func stateFitsActivityKitPayloadLimit() throws {
        let state = MissionActivityAttributes.ContentState(
            missionNumber: 99, missionTotal: 99,
            missionText: String(repeating: "あ", count: 200), landmarkName: "東京スカイツリー",
            distanceMeters: 12_345.678, heartRate: 182, indicator: MissionIndicator(segmentCount: 12, completedCount: 6),
            updatedAt: .now
        )
        let data = try JSONEncoder().encode(state)
        #expect(data.count < 4096)
    }
}

struct MissionLandmarkTests {
    @Test func presetsAreUniqueAndNonEmpty() {
        let names = MissionLandmark.presets.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
    }

    @Test func distanceBetweenKaminarimonAndSensoji() throws {
        let kaminarimon = try #require(MissionLandmark.presets.first { $0.name == "雷門" })
        let sensoji = try #require(MissionLandmark.presets.first { $0.name == "浅草寺" })
        let distance = kaminarimon.distance(to: sensoji.location)
        #expect(distance > 300 && distance < 600)
    }
}

struct HeartRatePhotoTriggerTests {
    @Test func showsAtThresholdAndHidesBelowRelease() {
        let trigger = HeartRatePhotoTrigger(threshold: 120, hysteresis: 10)
        #expect(!trigger.shouldShowPrompt(wasShowing: false, heartRate: 119))
        #expect(trigger.shouldShowPrompt(wasShowing: false, heartRate: 120))
        // Stays on while above the release threshold (hysteresis).
        #expect(trigger.shouldShowPrompt(wasShowing: true, heartRate: 115))
        #expect(trigger.shouldShowPrompt(wasShowing: true, heartRate: 111))
        #expect(!trigger.shouldShowPrompt(wasShowing: true, heartRate: 110))
    }

    @Test func disabledOrMissingReadingNeverShows() {
        let disabled = HeartRatePhotoTrigger(threshold: 100, isEnabled: false)
        #expect(!disabled.shouldShowPrompt(wasShowing: true, heartRate: 180))
        let enabled = HeartRatePhotoTrigger(threshold: 100)
        #expect(!enabled.shouldShowPrompt(wasShowing: true, heartRate: nil))
        #expect(!enabled.shouldShowPrompt(wasShowing: false, heartRate: .nan))
    }

    @Test func thresholdIsClamped() {
        #expect(HeartRatePhotoTrigger(threshold: 10).threshold == HeartRatePhotoTrigger.thresholdRange.lowerBound)
        #expect(HeartRatePhotoTrigger(threshold: 999).threshold == HeartRatePhotoTrigger.thresholdRange.upperBound)
        #expect(HeartRatePhotoTrigger(hysteresis: -5).hysteresis == 0)
    }
}

struct MissionContentStatePhotoPromptTests {
    @Test func decodesWithoutPhotoPromptKey() throws {
        let json = """
        {"missionNumber":1,"missionTotal":3,"missionText":"x","landmarkName":"雷門",
         "indicator":{"segmentCount":3,"completedCount":0,"highlightsActive":true},"updatedAt":0}
        """
        let state = try JSONDecoder().decode(MissionActivityAttributes.ContentState.self, from: Data(json.utf8))
        #expect(state.showsPhotoPrompt == false)
        #expect(state.heartRate == nil)
    }

    @Test func photoPromptRoundTrips() throws {
        let state = MissionActivityAttributes.ContentState(
            missionNumber: 1, missionTotal: 3, missionText: "x", landmarkName: "雷門",
            distanceMeters: nil, heartRate: 130, indicator: MissionIndicator(), updatedAt: Date(timeIntervalSince1970: 0),
            showsPhotoPrompt: true
        )
        let decoded = try JSONDecoder().decode(MissionActivityAttributes.ContentState.self,
                                               from: JSONEncoder().encode(state))
        #expect(decoded == state)
    }
}
