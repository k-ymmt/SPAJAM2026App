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
    var model = "gemini-3.6-flash"

    /// Secrets.plist にキーが無ければ nil(AI Studio キー優先、無ければ Google Cloud キー)
    static func fromSecrets() -> GeminiPhotoAIJudge? {
        guard let key = Secrets.googleAIStudioAPIKey ?? Secrets.googleCloudAPIKey else { return nil }
        return GeminiPhotoAIJudge(apiKey: key)
    }

    /// テキストのみの生成呼び出し(JSON モード)。プラン生成などに使う
    func generateText(prompt: String) async throws -> String {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url, timeoutInterval: 40)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["response_mime_type": "application/json"],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            NSLog("[PlanGen] gemini HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw URLError(.badServerResponse)
        }
        struct Res: Decodable {
            struct C: Decodable {
                struct Content: Decodable {
                    struct P: Decodable { let text: String? }
                    let parts: [P]?
                }
                let content: Content?
            }
            let candidates: [C]?
        }
        let decoded = try JSONDecoder().decode(Res.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(), !text.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return text
    }

    func judge(imageJPEG: Data, prompt: String) async throws -> (ok: Bool, reason: String) {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url, timeoutInterval: 25)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let instruction = """
        あなたは旅行ゲームのミッション判定員です。次の質問に写真だけを根拠に答えてください。
        質問: \(prompt)
        JSON で {"ok": true/false, "reason": "日本語で20文字程度の一言"} の形式のみで回答してください。
        reason は ok=true なら達成を褒める一言、false なら何が足りないかの一言にしてください。
        """

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": instruction],
                    ["inline_data": ["mime_type": "image/jpeg", "data": imageJPEG.base64EncodedString()]],
                ]
            ]],
            "generationConfig": ["response_mime_type": "application/json"],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[Judge] gemini HTTP \(code): \(String(data: data.prefix(300), encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }

        // candidates[0].content.parts[0].text に JSON 文字列が入る
        struct GenerateResponse: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String? }
                    let parts: [Part]?
                }
                let content: Content?
            }
            let candidates: [Candidate]?
        }
        struct Verdict: Decodable {
            let ok: Bool
            let reason: String?
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text,
              let verdictData = text.data(using: .utf8),
              let verdict = try? JSONDecoder().decode(Verdict.self, from: verdictData)
        else {
            throw URLError(.cannotParseResponse)
        }
        return (verdict.ok, verdict.reason ?? (verdict.ok ? "達成!" : "お題を満たしていないようです"))
    }
}
