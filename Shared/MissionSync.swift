//
//  MissionSync.swift
//  Shared (iOS / watchOS)
//
//  iPhone → Watch へ送る「いまのミッション」と単発イベント(達成・接近)。
//

import Foundation

/// Watch の W1 画面に表示するミッション状態
nonisolated struct MissionState: Codable, Sendable, Equatable {
    var planTitle: String
    var missionTitle: String
    var order: Int
    var total: Int
    var achievedCount: Int
}

nonisolated extension MissionState {
    static let payloadKey = "missionState"

    func payload() throws -> [String: Any] {
        [Self.payloadKey: try JSONEncoder().encode(self)]
    }

    init?(payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data,
              let decoded = try? JSONDecoder().decode(MissionState.self, from: data)
        else { return nil }
        self = decoded
    }
}

/// Watch へ送る単発イベント(触覚フィードバックのトリガー)
nonisolated enum WatchEventKind: String, Codable, Sendable {
    /// ミッション達成
    case achieved
    /// 目的地に接近
    case near

    static let payloadKey = "watchEvent"

    var payload: [String: Any] { [Self.payloadKey: rawValue] }

    init?(payload: [String: Any]) {
        guard let raw = payload[Self.payloadKey] as? String,
              let kind = WatchEventKind(rawValue: raw) else { return nil }
        self = kind
    }
}
