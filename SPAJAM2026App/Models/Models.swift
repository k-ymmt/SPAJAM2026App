//
//  Models.swift
//  SPAJAM2026App
//
//  プラン・ミッションのデータモデル。docs/mission-design.md の JSON スキーマと 1:1。
//

import Foundation

nonisolated enum MissionCategory: String, Codable, Sendable {
    case go, `do`, eat, face, pose, buy, find, quiz, thrill

    var label: String {
        switch self {
        case .go: "GO"
        case .do: "DO"
        case .eat: "EAT"
        case .face: "FACE"
        case .pose: "POSE"
        case .buy: "BUY"
        case .find: "FIND"
        case .quiz: "QUIZ"
        case .thrill: "THRILL"
        }
    }

    var symbolName: String {
        switch self {
        case .go: "mappin.and.ellipse"
        case .do: "camera"
        case .eat: "fork.knife"
        case .face: "face.smiling"
        case .pose: "figure.arms.open"
        case .buy: "bag"
        case .find: "magnifyingglass"
        case .quiz: "questionmark.circle"
        case .thrill: "heart.fill"
        }
    }
}

nonisolated enum SlotType: String, Codable, Sendable {
    case fixed, variable

    var label: String { self == .fixed ? "固定" : "変動" }
}

nonisolated enum CameraFacing: String, Codable, Sendable {
    case front, back
}

nonisolated struct GeoTarget: Codable, Sendable, Hashable {
    var latitude: Double
    var longitude: Double
    var radiusMeters: Double
}

nonisolated struct MissionJudgment: Codable, Sendable, Hashable {
    /// GPS 条件。nil なら位置判定はスキップ
    var location: GeoTarget?
    /// 写真 AI 判定のお題プロンプト。nil なら写真判定はスキップ
    var aiPrompt: String?
    /// THRILL 用: 安静時比の心拍上昇量 (bpm)
    var heartRateDelta: Int?
    /// QUIZ 用: 正解文字列
    var quizAnswer: String?
}

nonisolated struct Mission: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var order: Int
    var category: MissionCategory
    var slot: SlotType
    var title: String
    var judgment: MissionJudgment
    var points: Int
    var hapticOnNear: Bool?
    var camera: CameraFacing?
}

nonisolated struct TravelPlan: Codable, Sendable, Identifiable, Hashable {
    var planId: String
    var title: String
    var area: String
    var missions: [Mission]

    var id: String { planId }

    /// アプリ同梱のデモプランを読み込む
    static func bundledDemoPlan() -> TravelPlan {
        guard let url = Bundle.main.url(forResource: "demo-plan-asakusa", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(TravelPlan.self, from: data)
        else {
            fatalError("demo-plan-asakusa.json をバンドルから読み込めませんでした")
        }
        return plan
    }
}

/// ミッション達成のログ 1 件(= setlog 的タイル 1 枚)
nonisolated struct MissionRecord: Codable, Sendable, Identifiable {
    var missionId: String
    var achievedAt: Date
    /// 判定に使った写真(Documents 配下のファイル名)
    var photoFileName: String?
    var bpmAtAchieve: Int?
    var points: Int
    var aiComment: String?

    var id: String { missionId }
}

nonisolated struct HeartRateSample: Codable, Sendable {
    var date: Date
    var bpm: Double
}
