//
//  SampleSuggestions.swift
//  SPAJAM2026App
//
//  Fixture data used by SwiftUI previews and by the simulator stand-in picker.
//

import Foundation

extension SuggestionEntry {
    /// A copy with a fresh identity, as if it had just been picked.
    func refreshed() -> SuggestionEntry {
        SuggestionEntry(
            id: UUID(),
            title: title,
            dateInterval: dateInterval,
            pickedAt: .now,
            items: items.map {
                SuggestionItem(
                    id: UUID(),
                    kind: $0.kind,
                    headline: $0.headline,
                    details: $0.details,
                    imageURL: $0.imageURL
                )
            }
        )
    }
}

enum SampleSuggestions {
    static let all: [SuggestionEntry] = [
        SuggestionEntry(
            title: "鎌倉での一日",
            dateInterval: DateInterval(start: hoursAgo(30), duration: 6 * 3600),
            items: [
                SuggestionItem(
                    kind: .location,
                    headline: "鶴岡八幡宮",
                    details: ["鎌倉市", "35.3260, 139.5563"]
                ),
                SuggestionItem(kind: .photo, headline: "写真", details: ["撮影: 昨日 14:20"]),
                SuggestionItem(
                    kind: .motionActivity,
                    headline: "12,480 歩",
                    details: ["昨日 09:00 – 18:00"]
                )
            ]
        ),
        SuggestionEntry(
            title: "朝のランニング",
            dateInterval: DateInterval(start: hoursAgo(9), duration: 42 * 60),
            items: [
                SuggestionItem(
                    kind: .workout,
                    headline: "ランニング",
                    details: ["距離: 7.20 km", "消費エネルギー: 512 kcal", "平均心拍数: 148 bpm"]
                ),
                SuggestionItem(
                    kind: .song,
                    headline: "Sunrise Avenue",
                    details: ["The Morning Set", "再生: 今日 06:42"]
                )
            ]
        ),
        SuggestionEntry(
            title: "友人とのランチ",
            dateInterval: DateInterval(start: hoursAgo(52), duration: 90 * 60),
            items: [
                SuggestionItem(kind: .contact, headline: "佐藤 花子"),
                SuggestionItem(kind: .contact, headline: "鈴木 一郎"),
                SuggestionItem(
                    kind: .location,
                    headline: "代官山のカフェ",
                    details: ["渋谷区"]
                ),
                SuggestionItem(kind: .livePhoto, headline: "Live Photo")
            ]
        ),
        SuggestionEntry(
            title: "今日の気分をふりかえる",
            items: [
                SuggestionItem(
                    kind: .stateOfMind,
                    headline: "快適さ 0.62",
                    details: ["種別: 1日の気分", "ラベル: 2 件"]
                ),
                SuggestionItem(
                    kind: .reflection,
                    headline: "今日、感謝したことは何ですか？"
                )
            ]
        ),
        SuggestionEntry(
            title: "聴いたポッドキャスト",
            dateInterval: DateInterval(start: hoursAgo(20), duration: 55 * 60),
            items: [
                SuggestionItem(
                    kind: .podcast,
                    headline: "第 42 回: 旅と記録",
                    details: ["Daily Journal Radio", "再生: 昨日 21:10"]
                )
            ]
        )
    ]

    private static func hoursAgo(_ hours: Double) -> Date {
        Date(timeIntervalSinceNow: -hours * 3600)
    }
}
