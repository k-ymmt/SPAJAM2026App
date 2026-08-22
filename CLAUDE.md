# SPAJAM2026App

SPAJAM2026 ハッカソン用 iOS アプリ(作業用リポジトリ)。

## 開発環境

- Xcode 26.6 / Swift / SwiftUI
- iOS Deployment Target: 26.0 以上
- 基準デバイス: iPhone 17 Pro

## ブランチ戦略(必須ルール)

- **大元は `main` ブランチ(本番)**
- **`main` ブランチは直接触らない**(直接コミット・直接 push 禁止)
- 各メンバーは `main` から自分の作業ブランチを作成する
- 作業がひと段落したら `main` にマージする
- `main` が更新されたら、各自のブランチに取り込む(merge)

## 署名(必須ルール)

- `DEVELOPMENT_TEAM` はリポジトリ上は `8HUWJ2ZRK2` を正とし、**各自が Xcode でローカルに書き換える**(その変更はコミットしない)
- project.pbxproj をコミットするときは、`DEVELOPMENT_TEAM` の差分が混ざっていないか確認すること

## API キー(必須ルール)

- **API キーは絶対にリポジトリにコミットしない**
- `SPAJAM2026App/Secrets.sample.plist` を同フォルダに `Secrets.plist` としてコピーし、キーを記入して使う(`Secrets.plist` は gitignore 済み)
- キーの実体はチームのスプレッドシート「SPAJAM2026-ツナカン」を参照

## Firebase(複数人対応)

- Firebase プロジェクト: `spajam2026-app`(匿名認証 + Cloud Firestore Standard / asia-northeast1)
- SDK 設定ファイル `SPAJAM2026App/GoogleService-Info.plist` は **gitignore 済み**。`scripts/fetch-google-service-info.sh` で取得する(Firebase CLI ログインが必要)
  - 無い場合もアプリは起動するが、招待コードなど複数人機能だけ使えない(`FirebaseBootstrap`)
- Firestore のルール・インデックスは `firestore.rules` / `firestore.indexes.json`。変更したら `firebase deploy --only firestore:rules`
- データ構造: `rooms/{招待コード}`(親の uid・人数・status・公開された plan)、`rooms/{code}/members/{uid}`(子の名前)、`sessions/{uid}`(各ユーザーの進行状況)
- 親 = プラン作成者(`RoomMembership.Role.host`)、子 = 招待コードで参加した人(`guest`)。達成状況は uid ごとに別

### Claude Code への指示

- コミットが必要な変更は、必ず `main` 以外の作業ブランチ上で行うこと
- 現在のブランチが `main` の場合は、コミット前に作業ブランチへ切り替える(なければ `main` から作成する)
- `main` への反映はマージで行い、ユーザーの指示があったときのみ実施する
- 作業開始時・マージ前には `git fetch` して `origin/main` の更新を確認し、更新があれば作業ブランチに取り込む
