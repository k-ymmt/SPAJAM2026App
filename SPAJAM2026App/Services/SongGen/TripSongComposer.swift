//
//  TripSongComposer.swift
//  SPAJAM2026App
//
//  旅の結果から「旅のうた」を動的生成する:
//  ①スコアでムード判定 → ②Gemini でミッション内容から歌詞生成 →
//  ③Lyria 3 Clip(歌付き 30 秒 MP3)を生成。
//  再生はスライドショー+字幕+音源の同時再生(動画結合はしない)。
//  Lyria は有料ティア必須。失敗時は歌詞のみ(音源なし)で必ず ready に到達する。
//

import Foundation
import UIKit

/// 旅のうたのムード(スコア連動)
enum TripSongMood: String, CaseIterable, Identifiable {
    case high, low
    var id: String { rawValue }

    var label: String { self == .high ? "たのしい旅" : "しずかな旅" }

    /// Lyria に渡す曲調の指示
    var stylePrompt: String {
        switch self {
        case .high:
            "明るく楽しいアコースティックポップ。軽快なテンポ。日本語の歌詞を元気なボーカルが楽しそうに歌う。"
        case .low:
            "切なくしずかなスローバラード。ゆったりしたテンポ。日本語の歌詞をやさしいボーカルがしっとり歌う。"
        }
    }

    /// 歌詞生成に渡すトーンの指示
    var lyricsTone: String {
        switch self {
        case .high: "楽しかった旅を全力で祝う、明るく元気なトーン"
        case .low: "うまくいかなかった旅をやさしく肯定する、切なくもあたたかいトーン"
        }
    }

    /// スコアからムードを決める(達成数ベース。デモで調整しやすいよう 1 定数)
    static func from(achievedCount: Int) -> TripSongMood {
        achievedCount >= 3 ? .high : .low
    }
}

/// 完成した旅のうた
struct TripSong {
    /// 歌詞 1 行(start は曲頭からの秒。Lyria が歌唱タイミングを返す)
    struct Line: Hashable {
        var start: TimeInterval
        var text: String
    }

    /// 生成した MP3。Lyria 失敗時は nil(字幕のみ再生)
    var audioURL: URL?
    /// 表示用の歌詞行(歌唱タイミング付き)
    var lyricLines: [Line]
    var mood: TripSongMood
    /// 生成にかかった秒数(検証用)
    var latency: TimeInterval
    /// Lyria が失敗して音源なしになったか
    var audioUnavailable: Bool
}

@MainActor
@Observable
final class TripSongComposer {
    enum Phase {
        case idle
        case generating(String)   // 進捗表示用の文言
        case ready(TripSong)
    }

    private(set) var phase: Phase = .idle

    /// 歌の生成を開始する(多重起動は無視)。photos を渡すと写真の内容が歌詞に反映される
    func start(planTitle: String, area: String, missions: [Mission], achievedIds: Set<String>, partySize: Int, mood: TripSongMood? = nil, photos: [UIImage] = []) {
        if case .generating = phase { return }
        let resolvedMood = mood ?? .from(achievedCount: achievedIds.count)
        phase = .generating("ミザルが作詞中…")
        let startedAt = Date()

        Task {
            // ① 歌詞(失敗したらテンプレ)
            let lyrics = (try? await Self.generateLyrics(
                planTitle: planTitle, area: area, missions: missions,
                achievedIds: achievedIds, partySize: partySize, mood: resolvedMood,
                photos: photos
            )) ?? Self.fallbackLyrics(area: area, mood: resolvedMood)

            phase = .generating("ミザルが作曲中…(数十秒かかります)")

            // ② Lyria 3 Clip(失敗したら音源なしで進む)
            var result: SongGenService.SongResult?
            do {
                result = try await SongGenService.generateSong(lyrics: lyrics, mood: resolvedMood)
            } catch {
                NSLog("[Song] Lyria failed: \(error)")
            }

            // 歌唱タイミングが取れればそれを、なければ 30 秒を等分した時間割にする
            let lines = result?.timedLines ?? Self.evenlySpacedLines(from: lyrics)

            phase = .ready(TripSong(
                audioURL: result?.audioURL,
                lyricLines: lines,
                mood: resolvedMood,
                latency: Date().timeIntervalSince(startedAt),
                audioUnavailable: result == nil
            ))
        }
    }

    func reset() { phase = .idle }

    // MARK: - 歌詞生成(Gemini)

    private static func generateLyrics(
        planTitle: String, area: String, missions: [Mission],
        achievedIds: Set<String>, partySize: Int, mood: TripSongMood,
        photos: [UIImage]
    ) async throws -> String {
        guard let judge = GeminiPhotoAIJudge.fromSecrets() else { throw URLError(.userAuthenticationRequired) }
        let missionList = missions
            .map { "- \($0.title)(\(achievedIds.contains($0.id) ? "達成" : "未達成"))" }
            .joined(separator: "\n")
        // 写真は先頭 3 枚を縮小して渡す(トークン節約)
        let imagesJPEG = photos.prefix(3).compactMap { $0.resized(maxSide: 512).jpegData(compressionQuality: 0.5) }
        let prompt = """
        あなたは作詞家です。次の旅を 30 秒のうたにする日本語の歌詞を書いてください。

        旅: \(planTitle)(\(area)、\(partySize)人)
        ミッション:
        \(missionList)
        \(imagesJPEG.isEmpty ? "" : "添付の写真はこの旅で実際に撮った写真です。写っている情景・食べ物・人の様子を歌詞に具体的に織り込んでください。")

        ルール:
        - トーン: \(mood.lyricsTone)
        - [Verse] 4 行 + [Chorus] 4 行だけ。各行は 15 文字以内
        - ミッションの固有名詞(地名・食べ物など)を 2 つ以上入れる
        - 「スマホを見ない旅」がテーマ。説教くさくせず、情景で伝える

        JSON のみで回答:
        {"lyrics":"[Verse]\\n1行目\\n2行目\\n3行目\\n4行目\\n[Chorus]\\n1行目\\n2行目\\n3行目\\n4行目"}
        """
        let text = imagesJPEG.isEmpty
            ? try await judge.generateText(prompt: prompt)
            : try await judge.generateText(prompt: prompt, imagesJPEG: imagesJPEG)
        struct Res: Decodable { let lyrics: String }
        guard let data = text.data(using: .utf8),
              let res = try? JSONDecoder().decode(Res.self, from: data),
              !res.lyrics.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return res.lyrics
    }

    /// 歌詞生成に失敗したときのテンプレ
    private static func fallbackLyrics(area: String, mood: TripSongMood) -> String {
        switch mood {
        case .high:
            "[Verse]\n\(area)の風をあびて\nスマホは置いてきた\n知らない角を曲がれば\n心が先に走り出す\n[Chorus]\n見ざる聞かざる 気にしない\n今日のぜんぶが宝もの\n写真より覚えてる\nこの旅は目の前にある"
        case .low:
            "[Verse]\n\(area)の空はすこし遠くて\nうまく笑えない日もある\nそれでも歩いた道のりは\nちゃんとここに残ってる\n[Chorus]\n見ざるでいい 焦らなくていい\n次の旅がまた呼んでる\nポケットの中じゃなくて\n世界はいつも目の前にある"
        }
    }

    /// タイミング情報がないとき: タグを除いた行を 30 秒に等間隔で割り付ける
    private static func evenlySpacedLines(from lyrics: String) -> [TripSong.Line] {
        let texts = lyrics
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("[") }
        let interval = 30.0 / Double(max(1, texts.count))
        return texts.enumerated().map { i, text in
            TripSong.Line(start: Double(i) * interval, text: text)
        }
    }
}

// MARK: - Lyria 3 Clip

private extension UIImage {
    /// 長辺が maxSide になるよう縮小する
    func resized(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

enum SongGenService {
    enum SongError: Error { case noKey, badResponse, quotaOrAuth(String) }

    struct SongResult {
        var audioURL: URL
        /// Lyria が返す歌唱タイミング付き歌詞("[0.0:3.3] 行" 形式をパース)。無ければ nil
        var timedLines: [TripSong.Line]?
    }

    /// 実測済みレスポンス形式:
    /// { "status": "completed", "steps": [ { "content": [
    ///     {"type":"text","text":"[0.0:3.3] 歌詞行\n..."} |
    ///     {"type":"audio","mime_type":"audio/mpeg","data":"<base64>"} ] } ] }
    private struct Response: Decodable {
        struct Step: Decodable {
            struct Content: Decodable {
                let type: String
                let text: String?
                let data: String?
            }
            let content: [Content]?
        }
        let status: String?
        let steps: [Step]?
    }

    /// 歌付き 30 秒クリップを生成して MP3 とタイミング付き歌詞を返す
    static func generateSong(lyrics: String, mood: TripSongMood) async throws -> SongResult {
        guard let key = Secrets.googleAIStudioAPIKey else { throw SongError.noKey }

        var request = URLRequest(
            url: URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!,
            timeoutInterval: 150
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "model": "lyria-3-clip-preview",
            "input": "\(mood.stylePrompt)\n\(lyrics)",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard code == 200 else {
            let message = String(data: data.prefix(300), encoding: .utf8) ?? ""
            NSLog("[Song] Lyria HTTP \(code): \(message)")
            throw SongError.quotaOrAuth("HTTP \(code)")
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let contents = (decoded.steps ?? []).flatMap { $0.content ?? [] }

        guard let audioBase64 = contents.first(where: { $0.type == "audio" })?.data,
              let audio = Data(base64Encoded: audioBase64), audio.count > 10_000 else {
            NSLog("[Song] Lyria unexpected response: \(String(data: data.prefix(400), encoding: .utf8) ?? "")")
            throw SongError.badResponse
        }

        let url = FileManager.default.temporaryDirectory
            .appending(path: "trip-song-\(UUID().uuidString).mp3")
        try audio.write(to: url)

        let timedLines = contents.first(where: { $0.type == "text" })?.text.flatMap(parseTimedLines)
        return SongResult(audioURL: url, timedLines: timedLines)
    }

    /// "[0.0:3.3] 歌詞行" の並びをパースする
    static func parseTimedLines(_ text: String) -> [TripSong.Line]? {
        let lines: [TripSong.Line] = text
            .components(separatedBy: "\n")
            .compactMap { raw in
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard line.hasPrefix("["),
                      let close = line.firstIndex(of: "]"),
                      let colon = line[..<close].firstIndex(of: ":"),
                      let start = TimeInterval(line[line.index(after: line.startIndex)..<colon]) else {
                    return nil
                }
                let body = line[line.index(after: close)...].trimmingCharacters(in: .whitespaces)
                guard !body.isEmpty else { return nil }
                return TripSong.Line(start: start, text: body)
            }
        return lines.isEmpty ? nil : lines
    }
}
