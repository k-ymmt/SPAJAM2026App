//
//  MemoryEntryTests.swift
//  SPAJAM2026AppTests
//
//  リザルトの思い出カルーセルの項目の組み立て(時系列・ラベル)と、グラフカーソルのスナップ計算を検証する。
//

import Foundation
import Testing
@testable import SPAJAM2026App

struct MemoryEntryTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private var interval: DateInterval { DateInterval(start: start, duration: 3600) }
    private var timeline: HeartRateTimeline { HeartRateTimeline(samples: [], records: [], interval: interval) }

    private func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    private func mission(_ id: String, order: Int) -> Mission {
        Mission(id: id, order: order, category: .go, slot: .fixed, title: id, judgment: MissionJudgment(), points: 10)
    }

    @Test func entriesAreChronologicalAcrossKinds() {
        let entries = MemoryEntry.build(
            records: [
                MissionRecord(missionId: "b", achievedAt: at(45), bpmAtAchieve: 120, points: 10),
                MissionRecord(missionId: "a", achievedAt: at(15), points: 10),
                MissionRecord(missionId: "unknown", achievedAt: at(20), points: 10),
            ],
            missions: [mission("a", order: 1), mission("b", order: 2)],
            myMoments: [HeartMoment(id: "m1", capturedAt: at(30), bpm: 130)],
            otherMoments: [MemoryEntry.OtherMoment(id: "o1", ownerName: "たろう", capturedAt: at(6), bpm: nil)],
            timeline: timeline
        )
        #expect(entries.map(\.id) == ["other:o1", "mission:a", "moment:m1", "mission:b"])
        #expect(entries.map(\.label) == ["心が動いた瞬間", "MISSION 1", "心が動いた瞬間", "MISSION 2"])
        #expect(entries.map(\.isMine) == [false, true, true, true])
        #expect(entries.map(\.isMission) == [false, true, false, true])
        #expect(entries[0].position == 0.1)
        #expect(entries[3].position == 0.75)
        #expect(entries[3].bpm == 120)
        #expect(entries[1].kind == .mission(missionId: "a", order: 1))
        #expect(entries[0].kind == .heart(ownerName: "たろう"))
    }

    private var sample: [MemoryEntry] {
        [
            MemoryEntry(id: "a", kind: .mission(missionId: "a", order: 1), date: at(15), position: 0.25),
            MemoryEntry(id: "b", kind: .heart(ownerName: nil), date: at(30), position: 0.5),
            MemoryEntry(id: "c", kind: .mission(missionId: "c", order: 2), date: at(54), position: 0.9),
        ]
    }

    @Test func snapTargetRespectsRadius() {
        #expect(sample.nearest(to: 0.6)?.id == "b")
        #expect(sample.snapTarget(for: 0.52, radius: 0.05)?.id == "b")
        #expect(sample.snapTarget(for: 0.7, radius: 0.05) == nil)
        #expect([MemoryEntry]().snapTarget(for: 0.5, radius: 1) == nil)
    }

    @Test func fractionalIndexInterpolatesAndWraps() {
        #expect(sample.position(atFractionalIndex: 0) == 0.25)
        #expect(sample.position(atFractionalIndex: 1.5) == 0.7)
        // 末尾(0.9)→先頭(0.25)の間は端から端へ補間。3.0 は先頭と同じ
        #expect(abs(sample.position(atFractionalIndex: 2.5) - 0.575) < 1e-9)
        #expect(abs(sample.position(atFractionalIndex: 3) - 0.25) < 1e-9)
        #expect(abs(sample.position(atFractionalIndex: -0.5) - 0.575) < 1e-9)
        #expect([MemoryEntry]().position(atFractionalIndex: 2) == 0)
    }
}
