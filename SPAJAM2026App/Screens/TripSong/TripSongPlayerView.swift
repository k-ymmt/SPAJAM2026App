//
//  TripSongPlayerView.swift
//  SPAJAM2026App
//
//  旅のうたの全画面再生。写真スライドショー(Ken Burns)+歌詞字幕+Lyria の
//  MP3 を同時再生する(動画結合はしない)。ムードで色調を変える。
//

import AVFoundation
import SwiftUI

struct TripSongPlayerView: View {
    let song: TripSong
    let photos: [UIImage]
    @Environment(\.dismiss) private var dismiss

    @State private var photoIndex = 0
    @State private var lyricIndex = 0
    @State private var zooming = false
    @State private var player: AVAudioPlayer?
    @State private var showTasks: [Task<Void, Never>] = []
    /// 表示用に縮小した写真(フル解像度のまま全画面描画すると合成が壊れるため)
    @State private var displayPhotos: [UIImage] = []

    /// 1 枚あたりの表示秒数(30 秒 ÷ 枚数、最短 4 秒)
    private var photoInterval: TimeInterval {
        photos.isEmpty ? 6 : max(4, 30.0 / Double(photos.count))
    }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // スライドショー(写真がなければミザル)
            Group {
                if displayPhotos.isEmpty {
                    Image("MizaruCharacter")
                        .resizable()
                        .scaledToFit()
                        .padding(60)
                } else {
                    Image(uiImage: displayPhotos[photoIndex % displayPhotos.count])
                        .resizable()
                        .scaledToFill()
                        .id(photoIndex)
                        .transition(.opacity.animation(.easeInOut(duration: 0.8)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(zooming ? 1.15 : 1.0)
            .animation(.linear(duration: photoInterval), value: zooming)
            .clipped()
            // ムードの色調: low は彩度を落として青灰に
            .saturation(song.mood == .low ? 0.35 : 1.0)
            .overlay(song.mood == .low ? Color(red: 0.2, green: 0.3, blue: 0.4).opacity(0.25) : Color.clear)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // 下部グラデーション + 歌詞
            VStack {
                Spacer()
                if song.lyricLines.indices.contains(lyricIndex) {
                    Text(song.lyricLines[lyricIndex].text)
                        .font(.handTitle)
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.6), radius: 0.5)
                        .shadow(color: .black.opacity(0.8), radius: 6)
                        .multilineTextAlignment(.center)
                        .id(lyricIndex)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 70)
                }
            }
            .allowsHitTesting(false)
        }
        // 再生終了で自動的に閉じる仕様。途中でやめたい時はどこをタップしても閉じられる
        .contentShape(Rectangle())
        .onTapGesture {
            player?.stop()
            dismiss()
        }
        .overlay(alignment: .topLeading) {
            if song.audioUnavailable {
                Text("音源なし(歌詞のみ)")
                    .font(.handCaption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(24)
            }
        }
        .task { startShow() }
        .onDisappear {
            player?.stop()
            showTasks.forEach { $0.cancel() }
            showTasks = []
        }
    }

    private func startShow() {
        // 表示用に長辺 1500px へ縮小
        displayPhotos = photos.map { photo in
            let scale = min(1, 1500 / max(photo.size.width, photo.size.height))
            guard scale < 1 else { return photo }
            let newSize = CGSize(width: photo.size.width * scale, height: photo.size.height * scale)
            return UIGraphicsImageRenderer(size: newSize).image { _ in
                photo.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        // 音源(マナーモードでも鳴らす)
        if let url = song.audioURL {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
        zooming = true

        // 再生終了(曲の長さ、音源なしは 30 秒)で自動的に閉じる
        showTasks.append(Task {
            let duration = player?.duration ?? 30
            try? await Task.sleep(for: .seconds(duration + 0.5))
            guard !Task.isCancelled else { return }
            dismiss()
        })

        // スライド切り替え
        showTasks.append(Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(photoInterval))
                guard !Task.isCancelled else { return }
                withAnimation { photoIndex += 1 }
                zooming = false
                try? await Task.sleep(for: .milliseconds(50))
                zooming = true
            }
        })
        // 歌詞切り替え(Lyria の歌唱タイミングに同期。最後の行で止める)
        showTasks.append(Task {
            let lines = song.lyricLines
            let startedAt = Date()
            for (index, line) in lines.enumerated() where index > 0 {
                let wait = line.start - Date().timeIntervalSince(startedAt)
                if wait > 0 {
                    try? await Task.sleep(for: .seconds(wait))
                }
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.4)) { lyricIndex = index }
            }
        })
    }
}
