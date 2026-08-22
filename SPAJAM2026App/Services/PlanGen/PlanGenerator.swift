//
//  PlanGenerator.swift
//  SPAJAM2026App
//
//  プラン生成の 3 層ハイブリッド(docs/mission-design.md 6章):
//  ① 構造 = 固定3(GO+DO+EAT)+変動2(コードで固定)
//  ② 事実 = Google Geocoding / Places の実データ(エリア名・スポット・座標)
//  ③ 味付け = Gemini がお題文言と aiPrompt を生成(座標は書かせない)
//  どこかで失敗したら同梱デモプランにフォールバック。
//

import CoreLocation
import Foundation

struct NearbySpot: Sendable {
    var name: String
    var latitude: Double
    var longitude: Double
    var rating: Double?
}

enum TripMood: String, CaseIterable, Identifiable {
    case relaxed = "ゆったり"
    case active = "アクティブ"
    case mania = "マニア"

    var id: String { rawValue }

    /// 生成プロンプトに渡す温度感の説明
    var promptHint: String {
        switch self {
        case .relaxed: "ゆったり: のんびり歩いて楽しめる、難易度低めのお題にする"
        case .active: "アクティブ: よく歩き体を動かす、少し挑戦的なお題にする"
        case .mania: "マニア: 定番を外したニッチでディープなスポットや観察系のお題にする"
        }
    }
}

struct PlanGenerator {
    enum GenError: Error { case noKey, noArea, noSpots, badLLMOutput }

    /// ピン座標から主要エリアを推定してプランを生成する
    func generate(at coordinate: CLLocationCoordinate2D, partySize: Int, mood: TripMood) async throws -> TravelPlan {
        guard let mapsKey = Secrets.googleCloudAPIKey else { throw GenError.noKey }

        // ② 事実: エリア名(逆ジオコーディング)+ 主要スポット(注目度順)
        async let areaTask = reverseGeocode(coordinate, key: mapsKey)
        async let spotsTask = nearbySpots(coordinate, key: mapsKey)
        let (areaHint, spots) = try await (areaTask, spotsTask)
        guard !spots.isEmpty else { throw GenError.noSpots }

        // ③ 味付け: Gemini がスポットを選び、お題文言を書く
        let plan = try await composePlan(areaHint: areaHint, spots: spots, partySize: partySize, mood: mood)
        return plan
    }

    // MARK: - Google Geocoding

    private func reverseGeocode(_ c: CLLocationCoordinate2D, key: String) async throws -> String {
        var comp = URLComponents(string: "https://maps.googleapis.com/maps/api/geocode/json")!
        comp.queryItems = [
            .init(name: "latlng", value: "\(c.latitude),\(c.longitude)"),
            .init(name: "language", value: "ja"),
            .init(name: "key", value: key),
        ]
        struct Res: Decodable {
            struct R: Decodable { let formatted_address: String }
            let results: [R]
        }
        let (data, _) = try await URLSession.shared.data(from: comp.url!)
        let res = try JSONDecoder().decode(Res.self, from: data)
        return res.results.first?.formatted_address ?? "この周辺"
    }

    // MARK: - Google Places(注目度順 = 自然と主要地のスポットが返る)

    private func nearbySpots(_ c: CLLocationCoordinate2D, key: String) async throws -> [NearbySpot] {
        for radius in [5000, 15000, 30000] {
            var comp = URLComponents(string: "https://maps.googleapis.com/maps/api/place/nearbysearch/json")!
            comp.queryItems = [
                .init(name: "location", value: "\(c.latitude),\(c.longitude)"),
                .init(name: "radius", value: "\(radius)"),
                .init(name: "type", value: "tourist_attraction"),
                .init(name: "language", value: "ja"),
                .init(name: "key", value: key),
            ]
            struct Res: Decodable {
                struct R: Decodable {
                    struct G: Decodable {
                        struct L: Decodable { let lat: Double; let lng: Double }
                        let location: L
                    }
                    let name: String
                    let geometry: G
                    let rating: Double?
                }
                let results: [R]
            }
            let (data, _) = try await URLSession.shared.data(from: comp.url!)
            let res = try JSONDecoder().decode(Res.self, from: data)
            let spots = res.results.prefix(10).map {
                NearbySpot(name: $0.name, latitude: $0.geometry.location.lat, longitude: $0.geometry.location.lng, rating: $0.rating)
            }
            if spots.count >= 3 { return Array(spots) }
        }
        return []
    }

    // MARK: - Gemini でミッション文言を生成

    private func composePlan(areaHint: String, spots: [NearbySpot], partySize: Int, mood: TripMood) async throws -> TravelPlan {
        guard let judge = GeminiPhotoAIJudge.fromSecrets() else { throw GenError.noKey }
        let spotList = spots.enumerated()
            .map { i, s in "\(i): \(s.name)\(s.rating.map { "(評価\($0))" } ?? "")" }
            .joined(separator: "\n")

        let prompt = """
        あなたは旅行ゲームのプランナーです。以下の実在スポットだけを使って、日帰り旅のミッションを作ってください。

        エリア: \(areaHint)
        人数: \(partySize)人(\(partySize == 1 ? "ひとり旅" : "みんなで楽しめるお題も混ぜる"))
        温度感: \(mood.promptHint)
        スポット一覧(index: 名前):
        \(spotList)

        ルール:
        - ミッションは 5 つ。category は順に go, do, eat, face, pose
        - go は必ずスポットへ行くミッション。spotIndex に上の一覧の index を入れる
        - do は現地で写真を撮る系のお題(スポットに紐づくなら spotIndex も可)
        - eat はこの地域の名物料理を食べるお題(店は指定しない。有名な名物がなければ「地元の何かを食べる」系)
        - face は笑顔・表情系のお題、pose は「万歳する」など体のポーズ系のお題(お題は必ず万歳にする)
        - title は日本語で 20 文字以内。aiPrompt は「この写真に◯◯が写っていますか?」の形で、写真 1 枚で Yes/No 判定できる内容にする
        - 気分に合わせて難易度・トーンを調整する
        - areaName はエリアの短い呼び名(例: 新宿、浅草)

        JSON のみで回答:
        {"areaName":"...","title":"プラン名(15文字以内)","missions":[{"category":"go","title":"...","aiPrompt":"...","spotIndex":0}, ...]}
        """

        let text = try await judge.generateText(prompt: prompt)
        struct LLMPlan: Decodable {
            struct M: Decodable {
                let category: String
                let title: String
                let aiPrompt: String
                let spotIndex: Int?
            }
            let areaName: String
            let title: String
            let missions: [M]
        }
        guard let data = text.data(using: .utf8),
              let llm = try? JSONDecoder().decode(LLMPlan.self, from: data),
              llm.missions.count >= 5
        else { throw GenError.badLLMOutput }

        // ① 構造 + ②座標はコード側で確定(AI に座標を書かせない)
        let missions: [Mission] = llm.missions.prefix(5).enumerated().compactMap { i, m in
            guard let category = MissionCategory(rawValue: m.category) else { return nil }
            let slot: SlotType = (category == .face || category == .pose) ? .variable : .fixed
            var location: GeoTarget?
            if category == .go, let idx = m.spotIndex, spots.indices.contains(idx) {
                let s = spots[idx]
                location = GeoTarget(latitude: s.latitude, longitude: s.longitude, radiusMeters: 150)
            }
            return Mission(
                id: "gen-m\(i + 1)",
                order: i + 1,
                category: category,
                slot: slot,
                title: m.title,
                judgment: MissionJudgment(
                    location: location,
                    aiPrompt: m.aiPrompt
                ),
                points: slot == .fixed ? 10 : 15,
                hapticOnNear: category == .go ? true : nil,
                camera: category == .face ? .front : nil
            )
        }
        guard missions.count == 5 else { throw GenError.badLLMOutput }

        return TravelPlan(
            planId: "gen-\(UUID().uuidString.prefix(8))",
            title: llm.title,
            area: llm.areaName,
            missions: missions
        )
    }
}
