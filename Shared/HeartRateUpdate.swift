//
//  HeartRateUpdate.swift
//  SPAJAM2026TrialApp
//
//  Watch App と iOS App の両方のターゲットに属する共有モデル。
//

import Foundation

/// Apple Watch から iPhone へ送る心拍の一件分の更新。
nonisolated struct HeartRateUpdate: Codable, Sendable, Equatable {
    /// 直近の心拍数 (bpm)。計測開始直後などまだ値が無い場合は nil。
    var beatsPerMinute: Double?
    /// 心拍が計測された時刻。値が無い場合は状態が変わった時刻。
    var measuredAt: Date
    /// Watch 側が計測中かどうか。
    var isMeasuring: Bool

    static func stopped(at date: Date = Date()) -> HeartRateUpdate {
        HeartRateUpdate(beatsPerMinute: nil, measuredAt: date, isMeasuring: false)
    }
}

nonisolated extension HeartRateUpdate {
    /// WatchConnectivity のメッセージ／アプリケーションコンテキストで使うキー。
    static let payloadKey = "heartRateUpdate"

    /// plist 互換の辞書に変換する。`sendMessage` / `updateApplicationContext` にそのまま渡せる。
    func payload() throws -> [String: Any] {
        [Self.payloadKey: try JSONEncoder().encode(self)]
    }

    /// 受信した辞書から復元する。想定外の形式なら nil。
    init?(payload: [String: Any]) {
        guard let data = payload[Self.payloadKey] as? Data,
              let decoded = try? JSONDecoder().decode(HeartRateUpdate.self, from: data)
        else { return nil }
        self = decoded
    }
}
