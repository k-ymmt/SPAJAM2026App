//
//  TripMemberResultTests.swift
//  SPAJAM2026AppTests
//
//  リザルト共有用の結果の生成と、メンバー一覧の組み立てを検証する。
//

import Foundation
import Testing
@testable import SPAJAM2026App

@MainActor
struct TripMemberResultTests {
    private func makeSession(membership: RoomMembership?) -> TripSession {
        let plan = TravelPlan(planId: "p", title: "t", area: "a", missions: [])
        return TripSession(plan: plan, membership: membership)
    }

    @Test func memberResultUsesGuestNameAndHostFallback() {
        let guest = makeSession(membership: RoomMembership(code: "ABC234", role: .guest, name: "たろう"))
        #expect(guest.memberResult.name == "たろう")
        #expect(guest.memberResult.isHost == false)

        let host = makeSession(membership: RoomMembership(code: "ABC234", role: .host, name: nil))
        #expect(host.memberResult.name == "ホスト")
        #expect(host.memberResult.isHost == true)
        #expect(host.memberResult.bpmBars.count == 6)
    }

    @Test func partyPutsMeFirstAndExcludesOwnResult() {
        let session = makeSession(membership: RoomMembership(code: "ABC234", role: .host, name: nil))
        let now = Date()
        let results = [
            TripMemberResult(id: "me", name: "ホスト", isHost: true, questScore: 0, heartScore: 0, offlineScore: 0,
                             total: 0, achievedMissionIds: [], bpmBars: [], finishedAt: now),
            TripMemberResult(id: "u2", name: "たろう", isHost: false, questScore: 1, heartScore: 2, offlineScore: 3,
                             total: 6, achievedMissionIds: ["m1"], bpmBars: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6], finishedAt: now),
        ]
        let party = MemberResult.party(for: session, results: results, myUid: "me")
        #expect(party.count == 2)
        #expect(party[0].isMe)
        #expect(party[1].name == "たろう")
        #expect(party[1].total == 6)
        #expect(party[1].achievedMissionIds == ["m1"])
        #expect(party[1].bpmBars == [0.1, 0.2, 0.3, 0.4, 0.5, 0.6])
    }

    @Test func peakIsAvailableOnlyWhenBothFieldsArePresent() throws {
        let at = Date(timeIntervalSince1970: 1_750_000_000)
        var result = TripMemberResult(id: "u", name: "たろう", isHost: false, questScore: 1, heartScore: 2, offlineScore: 3,
                                      total: 6, achievedMissionIds: ["a"], bpmBars: [0.5], finishedAt: at)
        #expect(result.peak == nil)
        result.peakMissionId = "a"
        #expect(result.peak == nil)
        result.peakMissionAchievedAt = at
        #expect(result.peak == HeartRateTimeline.OtherPeak(id: "u", name: "たろう", missionId: "a", achievedAt: at))

        // 古いクライアントのドキュメント(peak 無し)も読める
        let legacy = """
        {"id":"u","name":"n","isHost":false,"questScore":0,"heartScore":0,"offlineScore":0,"total":0,
         "achievedMissionIds":[],"bpmBars":[],"finishedAt":0}
        """
        let decoded = try JSONDecoder().decode(TripMemberResult.self, from: Data(legacy.utf8))
        #expect(decoded.peak == nil)
    }

    @Test func resultRoundTripsThroughCodable() throws {
        let result = TripMemberResult(id: "u", name: "n", isHost: false, questScore: 1, heartScore: 2, offlineScore: 3,
                                      total: 6, achievedMissionIds: ["a"], bpmBars: [0.5], finishedAt: Date())
        let decoded = try JSONDecoder().decode(TripMemberResult.self, from: JSONEncoder().encode(result))
        #expect(decoded == result)
    }
}
