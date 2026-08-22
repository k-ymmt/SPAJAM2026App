//
//  GeminiPhotoAIJudge.swift
//  SPAJAM2026App
//
//  Gemini による写真 Yes/No 判定(Live 実装)。キーが無ければ生成に失敗して
//  呼び出し側で Mock にフォールバックする。
//

import Foundation

struct GeminiPhotoAIJudge: PhotoAIJudging {
    let apiKey: String
    /// 軽量で速い flash-lite を優先し、クォータ超過(429)などの場合は次のモデルへフォールバック
    var models = ["gemini-3.1-flash-lite", "gemini-3.6-flash"]

    /// Secrets.plist にキーが無ければ nil(AI Studio キー優先、無ければ Google Cloud キー)
    static func fromSecrets() -> GeminiPhotoAIJudge? {
        guard let key = Secrets.googleAIStudioAPIKey ?? Secrets.googleCloudAPIKey else { return nil }
        return GeminiPhotoAIJudge(apiKey: key)
    }

    /// 各モデルを順に試して最初に成功したレスポンスを返す
    private func generateContent(parts: [[String: Any]], timeout: TimeInterval) async throws -> Data {
        var lastError: Error = URLError(.badServerResponse)
        for model in models {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
            var request = URLRequest(url: url, timeoutInterval: timeout)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let body: [String: Any] = [
                "contents": [["parts": parts]],
                "generationConfig": ["response_mime_type": "application/json"],
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                if code == 200 { return data }
                NSLog("[Gemini] \(model) HTTP \(code) — 次のモデルへフォールバック")
                lastError = URLError(.badServerResponse)
            } catch {
                NSLog("[Gemini] \(model) error: \(error.localizedDescription) — 次のモデルへフォールバック")
                lastError = error
            }
        }
        throw lastError
    }

    private struct GenerateResponse: Decodable {
        struct C: Decodable {
            struct Content: Decodable {
                struct P: Decodable { let text: String? }
                let parts: [P]?
            }
            let content: Content?
        }
        let candidates: [C]?
    }

    private func extractText(_ data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(), !text.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return text
    }

    /// テキストのみの生成呼び出し(JSON モード)。プラン生成などに使う
    func generateText(prompt: String) async throws -> String {
        let data = try await generateContent(parts: [["text": prompt]], timeout: 60)
        return try extractText(data)
    }

    func judge(imageJPEG: Data, prompt: String) async throws -> (ok: Bool, reason: String) {
        let instruction = """
        あなたは旅行ゲームのミッション判定員です。次の質問に写真だけを根拠に答えてください。
        質問: \(prompt)
        JSON で {"ok": true/false, "reason": "日本語で20文字程度の一言"} の形式のみで回答してください。
        reason は ok=true なら達成を褒める一言、false なら何が足りないかの一言にしてください。
        """

        let data = try await generateContent(
            parts: [
                ["text": instruction],
                ["inline_data": ["mime_type": "image/jpeg", "data": imageJPEG.base64EncodedString()]],
            ],
            timeout: 30
        )

        struct Verdict: Decodable {
            let ok: Bool
            let reason: String?
        }
        let text = try extractText(data)
        guard let verdictData = text.data(using: .utf8),
              let verdict = try? JSONDecoder().decode(Verdict.self, from: verdictData)
        else {
            throw URLError(.cannotParseResponse)
        }
        return (verdict.ok, verdict.reason ?? (verdict.ok ? "達成!" : "お題を満たしていないようです"))
    }
}
