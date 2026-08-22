//
//  InviteCodeTests.swift
//  SPAJAM2026AppTests
//
//  招待コードの生成・正規化と、RoomMembership を含むスナップショットの往復を検証する。
//

import Foundation
import Testing
@testable import SPAJAM2026App

struct InviteCodeTests {
    @Test func generatedCodeUsesAlphabetAndLength() {
        for _ in 0..<50 {
            let code = InviteCode.generate()
            #expect(code.count == InviteCode.length)
            #expect(code.allSatisfy { InviteCode.alphabet.contains($0) })
        }
    }

    @Test func normalizeAcceptsLowercaseAndSpaces() {
        #expect(InviteCode.normalize(" ab cd ef ") == "ABCDEF")
        #expect(InviteCode.normalize("abcde") == nil)
        #expect(InviteCode.normalize("ABCD0I") == nil) // 0 と I は使わない
    }

    @Test func membershipRoundTripsThroughSnapshot() throws {
        let plan = TravelPlan(planId: "p", title: "t", area: "a", missions: [])
        var snapshot = TripSessionSnapshot(
            plan: plan, phase: .planning, currentMissionId: nil, records: [], heartRateSamples: [],
            useMockJudge: true, tripStartedAt: nil, tripEndedAt: nil, foregroundSeconds: 0,
            becameActiveAt: nil, restrictionAdjustments: 0, shieldSelectionData: nil, savedAt: Date()
        )
        snapshot.membership = RoomMembership(code: "ABC234", role: .guest, name: "たろう")
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(TripSessionSnapshot.self, from: data)
        #expect(decoded.membership == snapshot.membership)
    }
}
