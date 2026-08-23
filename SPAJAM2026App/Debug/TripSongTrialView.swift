//
//  TripSongTrialView.swift
//  SPAJAM2026App
//
//  旅のうた(歌詞生成 + Lyria 3 Clip + スライドショー再生)の検証画面。
//  進行中/終了済みの旅があればその実データ、なければデモプランで生成する。
//  検証が済んだらリザルト画面に組み込む。
//

import SwiftUI

struct TripSongTrialView: View {
    /// 進行中の旅(あれば実データを使う)
    var activeSession: TripSession?

    @State private var composer = TripSongComposer()
    @State private var mood: TripSongMood = .high
    @State private var isPlayerPresented = false

    private var plan: TravelPlan { activeSession?.plan ?? .bundledDemoPlan() }

    private var achievedIds: Set<String> {
        Set(activeSession?.records.map(\.missionId) ?? [])
    }

    private var photos: [UIImage] {
        guard let session = activeSession else { return [] }
        return session.records.compactMap { session.photo(for: $0) }
    }

    var body: some View {
        List {
            Section("入力") {
                LabeledContent("プラン", value: plan.title)
                LabeledContent("達成写真", value: "\(photos.count)枚")
                Picker("ムード", selection: $mood) {
                    ForEach(TripSongMood.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
            }

            Section("生成") {
                switch composer.phase {
                case .idle:
                    Button("旅のうたを生成する") {
                        composer.start(
                            planTitle: plan.title,
                            area: plan.area,
                            missions: plan.missions,
                            achievedIds: achievedIds,
                            partySize: plan.partySize ?? 1,
                            mood: mood
                        )
                    }
                case .generating(let message):
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(message)
                    }
                case .ready(let song):
                    LabeledContent("生成時間", value: String(format: "%.1f秒", song.latency))
                    LabeledContent("音源", value: song.audioUnavailable ? "なし(Lyria失敗/未課金)" : "あり")
                    ForEach(song.lyricLines, id: \.self) { line in
                        Text(line).font(.caption)
                    }
                    Button("再生する") { isPlayerPresented = true }
                    Button("作り直す", role: .destructive) { composer.reset() }
                }
            }
        }
        .navigationTitle("旅のうた検証")
        .fullScreenCover(isPresented: $isPlayerPresented) {
            if case .ready(let song) = composer.phase {
                TripSongPlayerView(song: song, photos: photos)
            }
        }
    }
}
