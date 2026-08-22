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
    enum GenError: Error { case noKey, noArea, noSpots, badLLMOutput, timeout }

    /// 生成全体のハードタイムアウト(秒)。電波不良でスピナーが回り続けるのを防ぐ
    static let overallTimeout: TimeInterval = 45

    /// ピン座標から主要エリアを推定してプランを生成する
    func generate(at coordinate: CLLocationCoordinate2D, partySize: Int, mood: TripMood) async throws -> TravelPlan {
        try await Self.withTimeout(seconds: Self.overallTimeout) {
            try await generateBody(at: coordinate, partySize: partySize, mood: mood)
        }
    }

    private func generateBody(at coordinate: CLLocationCoordinate2D, partySize: Int, mood: TripMood) async throws -> TravelPlan {
        guard let mapsKey = Secrets.googleCloudAPIKey else { throw GenError.noKey }

        // ② 事実: エリア名(逆ジオコーディング)+ 主要スポット(注目度順)
        async let areaTask = reverseGeocode(coordinate, key: mapsKey)
        async let spotsTask = nearbySpots(coordinate, key: mapsKey)
        let (areaHint, spots) = try await (areaTask, spotsTask)
        guard !spots.isEmpty else { throw GenError.noSpots }

        // ③ 味付け: Gemini がスポットを選び、お題文言を書く(一時エラーに備えて 1 回だけ自動リトライ)
        do {
            return try await composePlan(areaHint: areaHint, spots: spots, partySize: partySize, mood: mood)
        } catch {
            NSLog("[PlanGen] compose retrying after: \(error)")
            try Task.checkCancellation()
            return try await composePlan(areaHint: areaHint, spots: spots, partySize: partySize, mood: mood)
        }
    }

    /// work が seconds 以内に終わらなければ GenError.timeout を投げ、実行中の通信もキャンセルする
    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        _ work: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw GenError.timeout
            }
            guard let result = try await group.next() else { throw GenError.timeout }
            group.cancelAll()
            return result
        }
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
        let (data, _) = try await URLSession.shared.data(for: URLRequest(url: comp.url!, timeoutInterval: 10))
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
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: comp.url!, timeoutInterval: 10))
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

        // 人数ルールベース(docs/mission-design.md「人数ルールベース」準拠)
        let partyRule: String = switch partySize {
        case 1:
            """
            人数: 1人(ひとり旅)
            - お題はセルフィー・じっくり観察・内省系のトーン(「じぶんの◯◯」)にする
            - 判定基準: 人物は本人1人で OK。風景やモノだけの写真でも成立するお題にする
            - face は「自撮りで笑顔」、pose は「セルフ万歳」のように 1 人で完結させる
            """
        case 2:
            """
            人数: 2人
            - お題は「ふたりで◯◯」のペア系トーンにする
            - 判定基準: aiPrompt に「2人(以上)の人が写っていること」を必ず含める
            - face は「2人とも笑顔か」、pose は「2人とも万歳しているか」を aiPrompt に書く
            """
        default:
            """
            人数: \(partySize)人のグループ
            - お題は「全員で◯◯」のグループ系トーンにする(全員でジャンプ、全員で変顔 など)
            - 判定基準: aiPrompt に「\(partySize)人程度(またはそれ以上)の人が写っていること」を含める
            - face / pose は「写っている全員が条件を満たしているか」を aiPrompt に書く
            - 通行人の写り込みで落とさないよう「〜人以上」の表現にする
            """
        }

        let prompt = """
        あなたは旅行ゲームのプランナーです。以下の実在スポットだけを使って、日帰り旅のミッションを作ってください。

        エリア: \(areaHint)
        \(partyRule)
        温度感: \(mood.promptHint)
        スポット一覧(index: 名前):
        \(spotList)

        ルール:
        - ミッションは 5 つ。category は順に go, do, eat, face, pose
        - go は必ずスポットへ行くミッション。spotIndex に上の一覧の index を入れる
        - do は現地で写真を撮る系のお題。必ずどれかのスポットに紐づけ、spotIndex を入れる
        - eat はこの地域の名物料理を食べるお題(店は指定しない。有名な名物がなければ「地元の何かを食べる」系。spotIndex は入れない)
        - face は笑顔・表情系、pose は「万歳する」など体のポーズ系のお題(お題は必ず万歳にする)。どちらも「◯◯の前で」「◯◯をバックに」のように必ずどれかのスポットに紐づけ、spotIndex を入れる
        - go/do/face/pose の spotIndex はなるべく別々のスポットにする
        - title は日本語で 20 文字以内。aiPrompt は「この写真に◯◯が写っていますか?」の形で、写真 1 枚で Yes/No 判定できる内容にする
        - aiPrompt には上記の人数ルールに沿った人物条件を織り込むこと(1人なら人物条件なしでも可)
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
            // eat 以外は必ず座標を付ける(案内・接近振動・マップ用)。判定ゲートは go のみ。
            // LLM が spotIndex を返し忘れたら先頭スポットにフォールバック
            var location: GeoTarget?
            if category != .eat {
                let idx = m.spotIndex.flatMap { spots.indices.contains($0) ? $0 : nil } ?? 0
                let s = spots[idx]
                location = GeoTarget(latitude: s.latitude, longitude: s.longitude, radiusMeters: 150, name: s.name)
            }
            return Mission(
                id: "gen-m\(i + 1)",
                order: i + 1,
                category: category,
                slot: slot,
                title: m.title,
                judgment: MissionJudgment(
                    location: location,
                    locationRequired: category == .go ? true : nil,
                    aiPrompt: m.aiPrompt
                ),
                points: slot == .fixed ? 10 : 15,
                hapticOnNear: location != nil ? true : nil,
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
