//
//  TripSongTrialView.swift
//  SPAJAM2026App
//
//  旅のうた(歌詞生成 + Lyria 3 Clip + スライドショー再生)の検証画面。
//  本番はリザルト画面がセッションの達成写真とミッション結果を渡す。
//  ここではその代わりに、進行中の旅の実データ or 手動アップした写真で検証する。
//

import PhotosUI
import SwiftUI

struct TripSongTrialView: View {
    /// 進行中の旅(あれば実データを使う)
    var activeSession: TripSession?

    @State private var composer = TripSongComposer()
    @State private var mood: TripSongMood = .high
    @State private var isPlayerPresented = false
    @State private var pickedItems: [PhotosPickerItem] = []
    @State private var pickedImages: [UIImage] = []

    private var plan: TravelPlan { activeSession?.plan ?? .bundledDemoPlan() }

    private var achievedIds: Set<String> {
        Set(activeSession?.records.map(\.missionId) ?? [])
    }

    /// 検証用の写真: 手動アップ > 旅の達成写真(本番はリザルトが達成写真を渡す)
    private var photos: [UIImage] {
        if !pickedImages.isEmpty { return pickedImages }
        guard let session = activeSession else { return [] }
        return session.records.compactMap { session.photo(for: $0) }
    }

    var body: some View {
        List {
            Section("入力") {
                LabeledContent("プラン", value: plan.title)
                LabeledContent("写真", value: "\(photos.count)枚\(pickedImages.isEmpty ? "(旅の達成写真)" : "(手動アップ)")")
                PhotosPicker(selection: $pickedItems, maxSelectionCount: 5, matching: .images) {
                    Label("写真をアップ(仮入力)", systemImage: "photo.on.rectangle.angled")
                }
                if !pickedImages.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Array(pickedImages.enumerated()), id: \.offset) { _, image in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 64, height: 64)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
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
                            mood: mood,
                            photos: photos
                        )
                    }
                case .generating(let message):
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(message)
                    }
                case .ready(let song):
                    LabeledContent("生成時間", value: String(format: "%.1f秒", song.latency))
                    LabeledContent("音源", value: song.audioUnavailable ? "なし(Lyria失敗)" : "あり")
                    ForEach(song.lyricLines, id: \.self) { line in
                        Text("[\(String(format: "%.1f", line.start))s] \(line.text)")
                            .font(.caption)
                    }
                    Button("再生する") { isPlayerPresented = true }
                    Button("作り直す", role: .destructive) { composer.reset() }
                }
            }
        }
        .navigationTitle("旅のうた検証")
        .onChange(of: pickedItems) { _, items in
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                pickedImages = images
            }
        }
        .fullScreenCover(isPresented: $isPlayerPresented) {
            if case .ready(let song) = composer.phase {
                TripSongPlayerView(song: song, photos: photos)
            }
        }
    }
}
