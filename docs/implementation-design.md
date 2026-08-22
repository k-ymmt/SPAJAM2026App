# 実装設計

前提: iOS 26 / SwiftUI / iPhone 17 Pro 実機 + Apple Watch。提出は 2 日目 12:30。
方針: **すべてのサービスを protocol + Mock/Live の 2 実装**にし、API・実機・エンタイトルメントが揃わなくても UI とフローが常に動く状態を保つ。

## 1. ターゲット構成

| ターゲット | 役割 | 備考 |
|-----------|------|------|
| SPAJAM2026App (iOS) | 本体 | 既存 |
| TripActivityWidget (Widget Extension) | Live Activity(ロック画面/Dynamic Island) | 新規追加。ActivityKit |
| SPAJAM2026Watch (watchOS) | 心拍計測・触覚 FB・次ミッション表示 | `origin/watch` ブランチの実装を移植 |

共有コードは `Shared/` フォルダをターゲット間で共有(watch ブランチの `HeartRateUpdate.swift` 方式を踏襲)。

必要 Capability: HealthKit(Watch)/ Location / Family Controls(任意機能)/ Journaling Suggestions(`com.apple.developer.journal.allow`)。すべて実機必須。

## 2. フォルダ構成(Figma メモ「画面ごとにフォルダ」準拠)

```
SPAJAM2026App/
  App/            // App エントリ、AppState(@Observable)、DI
  Models/         // TravelPlan, Mission, MissionRecord, TripSession, HeartRateSample
  Services/
    PlanGen/      // PlanGenerator, PlacesClient, GeocodingClient, LLMClient
    Judgment/     // JudgmentEngine + 各 MissionJudge
    Location/     // LocationService(ジオフェンス・距離)
    HeartRate/    // PhoneHeartRateReceiver(WCSession)← watch ブランチ移植
    Camera/       // CameraService(AVFoundation)
    Restriction/  // ShieldService(FamilyControls。無効時は no-op)
    Sync/         // TripSyncService(招待コード同期。Mock=ローカル2人分)
    Journal/      // JournalingImporter(Suggestions 取り込み)
    LiveActivity/ // TripActivityController(開始/更新/終了)
  Screens/        // 画面ごとにフォルダ(Pencil の画面番号と対応)
    AreaSelect/   // 01 ピン設置→主要地スナップ
    Plan/         // 02 ミッションログ(setlog風タイル)
    Restriction/  // 06 おやすみにするアプリ
    Trip/         // 03 相当(アプリ内の旅行中ホーム/デバッグ用)
    MissionCamera// 04 撮影+判定
    Result/       // 05 個人リザルト
    Versus/       // 07 ふたりの旅くらべ
  Resources/      // demo-plan-asakusa.json(同梱デモプラン)
Shared/           // HeartRateUpdate, TripActivityAttributes(iOS/Watch/Widget 共有)
SPAJAM2026Watch/  // Watch UI(W1/W2)+ HeartRateWorkoutManager
TripActivityWidget/
```

## 3. データモデル(Codable、mission-design.md の JSON と 1:1)

```swift
struct TravelPlan: Codable {
    let planId: String
    let title: String
    let area: String
    let missions: [Mission]
}

enum MissionCategory: String, Codable { case go, do_, eat, face, pose, buy, find, quiz, thrill }
enum SlotType: String, Codable { case fixed, variable }

struct Mission: Codable, Identifiable {
    let id: String
    let order: Int
    let category: MissionCategory
    let slot: SlotType
    let title: String
    let judgment: Judgment
    var points: Int
    var hapticOnNear: Bool?
    var camera: CameraFacing?      // front / back
}

struct Judgment: Codable {
    var location: GeoTarget?       // nil なら GPS 判定スキップ
    var aiPrompt: String?          // photo 判定用
    var heartRateDelta: Int?       // thrill 用(+15 など)
    var quizAnswer: String?        // quiz 用
}

struct MissionRecord: Codable {    // 達成ログ(= setlog のタイル1枚)
    let missionId: String
    let achievedAt: Date
    let photoFileName: String?
    let bpmAtAchieve: Int?
    let points: Int
}

struct TripSession {               // @Observable な進行状態
    var plan: TravelPlan
    var currentIndex: Int
    var records: [MissionRecord]
    var heartRateSamples: [HeartRateSample]   // (date, bpm) 時系列
    var inviteCode: String
}
```

## 4. 判定エンジン

```swift
protocol MissionJudge {
    func judge(mission: Mission, input: JudgeInput) async -> JudgeResult
}
// JudgeInput: 写真(UIImage)+現在地+直近心拍。JudgeResult: .achieved(comment) / .failed(reason)

struct JudgmentEngine {
    // パイプライン: LocationJudge(条件があれば) → PhotoAIJudge(aiPromptがあれば)
    // 例外: thrill → HeartRateJudge、quiz → QuizJudge(文字列一致)
    // face/pose → ARKit がリアルタイム判定し UIImage を自動生成して同パイプラインへ合流
}
```

- **PhotoAIJudge(Live)**: 画像を JPEG 圧縮 → Gemini(チームの Google AI Studio キー)へ `aiPrompt` + 「JSON {"ok":bool,"reason":string} で答えて」。タイムアウト 10 秒
- **PhotoAIJudge(Mock)**: 2 秒待って必ず achieved(UI 開発・電波無しデモ用)。起動引数 or DEBUG メニューで切替
- **LocationJudge**: `CLLocation.distance(from:)` で半径判定のみ(ジオフェンス登録は接近通知用で、判定はその場計算)
- **HeartRateJudge**: 直近 60 秒の baseline 平均 + delta 超過を検知
- **FaceJudge**: ARFaceTrackingConfiguration の blendShapes(mouthSmileLeft/Right > 0.6 を 1 秒継続)→ フレームをキャプチャして achieved

## 5. 主要フロー

```
[プラン作成] AreaSelect → (Live: Geocoding+Places+LLM / Mock: 同梱JSON) → TravelPlan
  → TripSyncService.create(inviteCode) で共有(相手は join(code) で同じ JSON を取得)

[旅行開始] Plan 画面 →「旅をはじめる」
  → ShieldService.start(選択カテゴリ)      // 失敗しても続行(任意機能)
  → TripActivityController.start(plan)     // Live Activity 開始
  → Watch へ WCSession で planStart 送信    // HR ワークアウト開始・W1 表示
  → LocationService.monitor(現ミッション)  // 接近で Watch 触覚

[ミッション実施] 通知/Watch → アプリを開く → MissionCamera
  → 撮影 → JudgmentEngine.judge()
  → 達成: record 追加・LA 更新・Watch へ達成+触覚・次ミッションへ
  → 未達: reason 表示 → リトライ

[旅行終了] 全達成 or 手動終了
  → ShieldService.stop() / LA 終了 / Watch ワークアウト終了
  → FocusScore = Σ|bpm - 移動平均| / 時間で正規化
  → JournalingImporter で写真・訪問地を取り込み(実機のみ・失敗時は自前ログのみ)
  → Result → Versus(TripSyncService から相手の records/samples 取得)
```

## 6. 同期(対戦)

- **Live**: Firebase Firestore。`trips/{inviteCode}` に plan、`trips/{code}/players/{id}` に records と HR サンプル(間引き 1/10s)。リアルタイムリスナーで Versus 画面更新
- **Mock**: 相手プレイヤーのダミーデータを生成して返す(**Versus 画面は同期実装ゼロでもデモ可能**)
- Firestore セットアップが 30 分で終わらなければ Mock のまま発表に振り切る判断もあり

## 7. Live Activity

- `TripActivityAttributes`(static: planTitle)+ `ContentState`(missionTitle, order, total, distanceText, bpm)
- 更新はアプリ内から `Activity.update()`(push 不要)。bpm 更新は 15 秒間引き
- Dynamic Island 対応は compact(order/total + ハート)だけ実装、余裕があれば expanded

## 8. 実装優先度(P0 = 明日 12:30 に必ず動くもの)

| P | 項目 | 依存 |
|---|------|------|
| **P0** | Models + 同梱デモプラン JSON | なし |
| **P0** | Plan / MissionCamera / Result 画面(Mock 判定で一周) | Models |
| **P0** | PhotoAIJudge Live(Gemini) | API キー(済) |
| **P0** | Watch 心拍ストリーミング移植 + 達成触覚 | watch ブランチ(済) |
| **P0** | Live Activity(次ミッション表示) | Widget Extension |
| P1 | AreaSelect(ピン→スナップ)+ プラン生成 Live | Places/Geocoding |
| P1 | Versus 画面(Mock 対戦データ) | Models |
| P1 | FACE 判定(ARKit 笑顔) | 実機 |
| P1 | Firestore 同期 | Firebase 設定 |
| P2 | ShieldService(FamilyControls) | 実機+capability |
| P2 | JournalingImporter | entitlement+実機 |
| P2 | POSE / QUIZ 判定 | — |

**デモの成立条件 = P0 だけで「プラン表示 → 撮影 → AI 判定 → Watch 触覚 → リザルト」が一周すること。** P1 以降は上から順に積む。

## 9. 分担案(議事録の役割ベース)

- **多田**: Models・デモプラン JSON・PlanGen(生成プロンプト)・JudgmentEngine
- **山本**: Watch 移植・Live Activity・Journaling(API 検証の続き)・Firebase
- **広瀬/杉浦**: Screens 実装(Pencil デザイン準拠)・アセット

## 10. リスクと逃げ道

- **AI 判定が不安定** → Mock 切替スイッチを常備。デモは電波状況次第で Mock
- **Face Tracking とカメラ判定の競合**(AVCaptureSession と ARSession は同時不可)→ 画面遷移で完全に分離する
- **Journaling Suggestions が空**(実機に履歴がないと候補が出ない)→ 自前の MissionRecord だけでレポート成立する設計にする
- **FamilyControls の認可拒否/失敗** → 制限なしで旅行は続行できる(任意機能として実装)
