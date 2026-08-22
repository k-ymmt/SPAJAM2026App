//
//  TripSessionPersistenceTests.swift
//  SPAJAM2026AppTests
//
//  TripSession がキル後に復元できること(スナップショットの保存・読み戻し)を検証する。
//

import Foundation
import Testing
@testable import SPAJAM2026App

@MainActor
struct TripSessionPersistenceTests {
    private func isolatedDefaults() -> UserDefaults {
        let suite = "TripSessionPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func plan() -> TravelPlan {
        TravelPlan(planId: "p1", title: "テスト旅", area: "浅草", missions: [
            Mission(id: "m1", order: 1, category: .go, slot: .fixed, title: "雷門", judgment: .init(), points: 10),
            Mission(id: "m2", order: 2, category: .eat, slot: .fixed, title: "人形焼", judgment: .init(), points: 20),
        ])
    }

    @Test func snapshotRoundTripsThroughStore() {
        TripSessionStore.defaults = isolatedDefaults()
        defer { TripSessionStore.clear() }

        let session = TripSession(plan: plan())
        session.proceedToRestrictionSetup()
        session.startTrip()

        let saved = TripSessionStore.load()
        #expect(saved != nil)
        #expect(saved?.phase == .traveling)
        #expect(saved?.currentMissionId == "m1")
        #expect(saved?.plan == plan())
    }

    @Test func restoreRebuildsTravelingSession() {
        TripSessionStore.defaults = isolatedDefaults()
        defer { TripSessionStore.clear() }

        let started = Date(timeIntervalSinceNow: -600)
        let snapshot = TripSessionSnapshot(
            plan: plan(),
            phase: .traveling,
            currentMissionId: "m2",
            records: [MissionRecord(missionId: "m1", achievedAt: Date(), photoFileName: nil, bpmAtAchieve: 80, points: 10, aiComment: nil)],
            heartRateSamples: [],
            useMockJudge: true,
            tripStartedAt: started,
            tripEndedAt: nil,
            foregroundSeconds: 60,
            becameActiveAt: Date(timeIntervalSinceNow: -120),
            restrictionAdjustments: 1,
            shieldSelectionData: nil,
            savedAt: Date(timeIntervalSinceNow: -60)
        )
        TripSessionStore.save(snapshot)

        let restored = TripSession.restore()
        #expect(restored != nil)
        #expect(restored?.phase == .traveling)
        #expect(restored?.currentMission?.id == "m2")
        #expect(restored?.records.map(\.missionId) == ["m1"])
        #expect(restored?.questScore == 10)
        #expect(restored?.adjustPenalty == 5)
        #expect(restored?.isAchieved(plan().missions[0]) == true)
        // 前面時間: 60s + (savedAt - becameActiveAt = 60s) = 120s が確定済みになり、残りが「みない時間」
        #expect(restored?.snapshot.foregroundSeconds == 120)
        #expect(restored?.snapshot.becameActiveAt == nil)
    }

    @Test func restoreReturnsNilWhenNothingSaved() {
        TripSessionStore.defaults = isolatedDefaults()
        #expect(TripSession.restore() == nil)
    }

    @Test func discardClearsStore() {
        TripSessionStore.defaults = isolatedDefaults()

        let session = TripSession(plan: plan())
        session.persist()
        #expect(TripSessionStore.load() != nil)

        session.discard()
        #expect(TripSessionStore.load() == nil)
    }
}
