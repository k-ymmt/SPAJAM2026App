//
//  JudgmentEngine.swift
//  SPAJAM2026App
//
//  全ミッション共通の判定パイプライン(docs/mission-design.md 準拠):
//  撮影 → [GPS 条件] → [AI 画像判定] → 達成 / 未達(理由つき)
//

import CoreLocation
import Foundation
import UIKit

struct JudgeInput {
    var image: UIImage?
    var location: CLLocation?
    /// 直近の心拍 (bpm)
    var currentBPM: Double?
    /// 旅行開始からの安静時基準 (bpm)
    var baselineBPM: Double?
    /// QUIZ の回答
    var answerText: String?
}

enum JudgeResult {
    case achieved(comment: String)
    case failed(reason: String)
}

protocol PhotoAIJudging: Sendable {
    /// 写真がお題(prompt)を満たすかを Yes/No で判定する
    func judge(imageJPEG: Data, prompt: String) async throws -> (ok: Bool, reason: String)
}

struct JudgmentEngine {
    var photoJudge: any PhotoAIJudging

    func judge(mission: Mission, input: JudgeInput) async -> JudgeResult {
        // 1. GPS 条件(locationRequired のミッションのみ。それ以外の location は案内・接近振動専用)
        if mission.judgment.locationRequired == true, let target = mission.judgment.location {
            guard let location = input.location else {
                return .failed(reason: "現在地が取得できませんでした")
            }
            let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
            let distance = location.distance(from: targetLocation)
            if distance > target.radiusMeters {
                return .failed(reason: "目的地まであと \(Int(distance))m。もう少し近づこう")
            }
        }

        // 2. THRILL: 心拍上昇の確認(写真判定より優先して評価)
        if let delta = mission.judgment.heartRateDelta {
            if let current = input.currentBPM, let baseline = input.baselineBPM {
                if current - baseline < Double(delta) {
                    return .failed(reason: "まだドキドキが足りない(+\(Int(current - baseline))bpm / 目標 +\(delta)bpm)")
                }
            }
            // Watch 未接続時は写真判定のみで通す(デモ用フォールバック)
        }

        // 3. QUIZ: 文字列一致
        if let answer = mission.judgment.quizAnswer {
            guard let text = input.answerText?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else {
                return .failed(reason: "答えを入力してください")
            }
            return text == answer
                ? .achieved(comment: "正解!")
                : .failed(reason: "残念、もう一度観察してみよう")
        }

        // 4. AI 画像判定
        if let prompt = mission.judgment.aiPrompt {
            guard let image = input.image,
                  let jpeg = image.jpegData(compressionQuality: 0.5) else {
                return .failed(reason: "写真を撮ってください")
            }
            do {
                let result = try await photoJudge.judge(imageJPEG: jpeg, prompt: prompt)
                return result.ok
                    ? .achieved(comment: result.reason)
                    : .failed(reason: result.reason)
            } catch {
                NSLog("[Judge] photo judge failed: \(error)")
                return .failed(reason: "判定に失敗しました(通信エラー)。リトライしてください")
            }
        }

        return .achieved(comment: "達成!")
    }
}

/// Mock 判定: 常に 2 秒後に達成。電波なし・API 障害時のデモ用
struct MockPhotoAIJudge: PhotoAIJudging {
    func judge(imageJPEG: Data, prompt: String) async throws -> (ok: Bool, reason: String) {
        try await Task.sleep(for: .seconds(2))
        return (true, "お題をクリアしました!(Mock 判定)")
    }
}
