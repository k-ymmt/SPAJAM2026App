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

    /// 1 枚あたりの表示秒数(30 秒 ÷ 枚数、最短 4 秒)
    private var photoInterval: TimeInterval {
        photos.isEmpty ? 6 : max(4, 30.0 / Double(photos.count))
    }


    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // スライドショー(写真がなければミザル)
            Group {
                if photos.isEmpty {
                    Image("MizaruCharacter")
                        .resizable()
                        .scaledToFit()
                        .padding(60)
                } else {
                    Image(uiImage: photos[photoIndex % photos.count])
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
        // 閉じるは ZStack の外側 overlay に置く(transition 中の画像レイヤーより必ず上に描画される)
        .overlay(alignment: .topTrailing) {
            Button {
                player?.stop()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.45), in: Circle())
                    .contentShape(Circle())
            }
            .padding(20)
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
        // 音源(マナーモードでも鳴らす)
        if let url = song.audioURL {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = try? AVAudioPlayer(contentsOf: url)
            player?.play()
        }
        zooming = true

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
