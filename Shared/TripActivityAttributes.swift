//
//  TripActivityAttributes.swift
//  Shared (iOS / Widget)
//
//  旅行中の Live Activity に表示する状態。watchOS では ActivityKit が無いためコンパイル対象外。
//

#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 現在のミッションのタイトル(例: 仲見世で いちばん赤いものを撮る)
        var missionTitle: String
        /// 何番目のミッションか(1 始まり)
        var missionOrder: Int
        /// ミッション総数
        var missionTotal: Int
        /// 目的地までの距離表示(例: あと 120m)。GPS 条件が無いミッションでは nil
        var distanceText: String?
        /// 直近の心拍 (bpm)。未計測は nil
        var bpm: Int?
    }

    /// プラン名(例: 浅草 まったり旅)
    var planTitle: String
}
#endif
