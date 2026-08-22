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

/// Watch へ送る単発イベントの種類(触覚フィードバックのトリガー)
nonisolated enum WatchEventKind: String, Codable, Sendable {
    /// 自分がミッション達成
    case achieved
    /// 目的地に接近
    case near
    /// 心拍が高まった(写真を撮るチャンス)
    case heartSpike
    /// 自分以外のメンバーがミッション達成
    case memberAchieved
}

/// Watch へ送る単発イベント。text は Watch 画面に短く出す表示用文言
nonisolated struct WatchEvent: Sendable {
    var kind: WatchEventKind
    var text: String?

    static let kindKey = "watchEvent"
    static let textKey = "watchEventText"

    var payload: [String: Any] {
        var p: [String: Any] = [Self.kindKey: kind.rawValue]
        if let text { p[Self.textKey] = text }
        return p
    }

    init(kind: WatchEventKind, text: String? = nil) {
        self.kind = kind
        self.text = text
    }

    init?(payload: [String: Any]) {
        guard let raw = payload[Self.kindKey] as? String,
              let kind = WatchEventKind(rawValue: raw) else { return nil }
        self.kind = kind
        self.text = payload[Self.textKey] as? String
    }
}
