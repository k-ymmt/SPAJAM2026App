//
//  TripMemberResult.swift
//  SPAJAM2026App
//
//  旅が終わったメンバー 1 人分の結果。リザルト「みんなの旅の記録」で共有する。
//  Firestore: rooms/{code}/results/{uid}
//

import Foundation

nonisolated struct TripMemberResult: Codable, Sendable, Identifiable, Equatable {
    /// uid
    var id: String
    var name: String
    var isHost: Bool
    var questScore: Int
    var heartScore: Int
    var offlineScore: Int
    var total: Int
    var achievedMissionIds: [String]
    /// 時間帯ごとの心拍変動量(6 区間・正規化済み 0...1)
    var bpmBars: [Double]
    var finishedAt: Date
    /// 自分の心拍が最も高かった時刻に近いミッション(リザルトのバー上ピン用)。古いクライアントからは nil
    var peakMissionId: String?
    /// `peakMissionId` を達成した時刻(ピンの横位置に使う)
    var peakMissionAchievedAt: Date?

    /// リザルトのバー上ピンに使える形(未送信・未達成なら nil)
    var peak: HeartRateTimeline.OtherPeak? {
        guard let peakMissionId, let peakMissionAchievedAt else { return nil }
        return .init(id: id, name: name, missionId: peakMissionId, achievedAt: peakMissionAchievedAt)
    }
}
