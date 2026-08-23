//
//  HeartRateTimelineTests.swift
//  SPAJAM2026AppTests
//
//  リザルト「ドキドキ ログ」の集計(区間最大・ミッション位置・ピーク・心が動いた回数)を検証する。
//

import Foundation
import Testing
@testable import SPAJAM2026App

struct HeartRateTimelineTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private var interval: DateInterval { DateInterval(start: start, duration: 3600) }

    private func sample(_ minutes: Double, _ bpm: Double) -> HeartRateSample {
        HeartRateSample(date: start.addingTimeInterval(minutes * 60), bpm: bpm)
    }

    private func record(_ id: String, minutes: Double) -> MissionRecord {
        MissionRecord(missionId: id, achievedAt: start.addingTimeInterval(minutes * 60), points: 10)
    }

    @Test func barsTakeMaximumPerSlotAndMarkPeak() {
        // 6 区間 × 10 分。0-10 分は 60/80 の最大 80, 30-40 分に 120
        let timeline = HeartRateTimeline(
            samples: [sample(1, 60), sample(5, 80), sample(35, 120)],
            records: [],
            interval: interval,
            barCount: 6
        )
        #expect(timeline.bars.count == 6)
        #expect(timeline.bars[0].bpm == 80)
        #expect(timeline.bars[0].hasSamples)
        #expect(timeline.bars[3].bpm == 120)
        #expect(timeline.peakBar?.index == 3)
        #expect(timeline.bars[3].level == 1)
        #expect(timeline.bars[0].level == 0)
        #expect(timeline.maximumBpm == 120)
    }

    @Test func emptySlotsAreInterpolated() {
        let timeline = HeartRateTimeline(
            samples: [sample(5, 60), sample(25, 100)],
            records: [],
            interval: interval,
            barCount: 6
        )
        // 区間 1 は 60→100 の中間
        #expect(timeline.bars[1].bpm == 80)
        #expect(!timeline.bars[1].hasSamples)
        // 末尾は最寄りの実測値
        #expect(timeline.bars[5].bpm == 100)
    }

    @Test func markersFollowTripInterval() {
        let timeline = HeartRateTimeline(
            samples: [],
            records: [record("b", minutes: 45), record("a", minutes: 15)],
            interval: interval,
            barCount: 4
        )
        #expect(timeline.markers.map(\.missionId) == ["a", "b"])
        #expect(timeline.markers[0].position == 0.25)
        #expect(timeline.markers[0].barIndex == 1)
        #expect(timeline.markers[1].barIndex == 3)
        #expect(timeline.marker(nearestTo: 0)?.missionId == "a")
        #expect(timeline.marker(nearestTo: 3)?.missionId == "b")
        #expect(!timeline.hasSamples)
    }

    @Test func markerOutsideIntervalIsClamped() {
        let timeline = HeartRateTimeline(
            samples: [],
            records: [record("late", minutes: 90)],
            interval: interval,
            barCount: 4
        )
        #expect(timeline.markers[0].position == 1)
        #expect(timeline.markers[0].barIndex == 3)
    }

    @Test func intervalIsEstimatedWhenMissing() {
        let timeline = HeartRateTimeline(
            samples: [sample(10, 70)],
            records: [record("a", minutes: 40)],
            interval: nil
        )
        #expect(timeline.interval.start == start.addingTimeInterval(10 * 60 - 600))
        #expect(timeline.interval.end == start.addingTimeInterval(40 * 60 + 600))
    }

    @Test func spikesNeedHistoryAndRespectCooldown() {
        var samples = (0..<6).map { sample(Double($0), 70) }
        samples.append(sample(6, 90))   // +20 → spike
        samples.append(sample(7, 95))   // cooldown 中
        samples.append(sample(12, 110)) // 5 分後 → spike
        let timeline = HeartRateTimeline(samples: samples, records: [], interval: interval)
        #expect(timeline.spikeCount == 2)

        let flat = HeartRateTimeline(samples: (0..<10).map { sample(Double($0), 70) }, records: [], interval: interval)
        #expect(flat.spikeCount == 0)
    }

    @Test func demoSamplesRiseAroundMissions() {
        let records = [record("a", minutes: 30)]
        let samples = HeartRateTimeline.demoSamples(records: records, interval: interval)
        #expect(!samples.isEmpty)
        let timeline = HeartRateTimeline(samples: samples, records: records, interval: interval, barCount: 6)
        #expect(timeline.peakBar?.index == 3)
        #expect(timeline.marker(nearestTo: 3)?.missionId == "a")
    }

    @Test func peakMissionsFollowHighestSamplesWithoutDuplicates() {
        // 最高 130 は 42 分(b に近い)、2 番目 120 は 40 分(同じく b)、3 番目 100 は 12 分(a に近い)
        let timeline = HeartRateTimeline(
            samples: [sample(12, 100), sample(40, 120), sample(42, 130), sample(5, 70)],
            records: [record("a", minutes: 15), record("b", minutes: 45), record("c", minutes: 55)],
            interval: interval
        )
        #expect(timeline.peakMissionIds == ["b", "a"])
        #expect(timeline.peakMissionId == "b")
        #expect(timeline.position(of: start.addingTimeInterval(45 * 60)) == 0.75)
        #expect(timeline.date(at: 0.75) == start.addingTimeInterval(45 * 60))
        #expect(timeline.date(at: 1.5) == timeline.interval.end)
        #expect(timeline.date(at: -1) == timeline.interval.start)
    }

    @Test func peakMissionsAreEmptyWithoutRecordsOrSamples() {
        #expect(HeartRateTimeline(samples: [sample(1, 90)], records: [], interval: interval).peakMissionIds.isEmpty)
        #expect(HeartRateTimeline(samples: [], records: [record("a", minutes: 1)], interval: interval).peakMissionIds.isEmpty)
    }
}
