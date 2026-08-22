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
}
