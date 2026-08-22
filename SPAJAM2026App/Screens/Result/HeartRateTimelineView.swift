//
//  HeartRateTimelineView.swift
//  SPAJAM2026App
//
//  リザルトの「ミッション写真 ↔ 心拍バー」同期ビュー(Figma 旅後/結果画面 ver2)。
//  上段: 選択中ミッションの写真(中央・大)と前後のミッション(左右・小)+ 右端に自分のアバター
//  中段: 旅の時間軸。ミッション達成時刻にピン(選択中は大きいピン)、右端はハート入りのゴールピン
//  下段: 時間帯ごとの心拍バー(クリーム帯)。選択ミッションの区間をグレーのカーソルで示し、ピークを強調
//  バーをタップすると最寄りのミッションを選択し、写真も切り替わる(心拍は自分の分だけ)。
//

import SwiftUI

struct HeartRateTimelineView: View {
    let timeline: HeartRateTimeline
    /// 時間順のミッション(達成したものだけ)
    let missions: [Mission]
    let photo: (Mission) -> UIImage?
    @Binding var selectedMissionId: String?

    private var selectedIndex: Int? {
        missions.firstIndex { $0.id == selectedMissionId }
    }

    private var selectedMarker: HeartRateTimeline.Marker? {
        timeline.markers.first { $0.missionId == selectedMissionId }
    }

    var body: some View {
        VStack(spacing: 10) {
            photoStrip
            timelineAxis
            heartLog
            dashedSeparator
        }
    }

    // MARK: - 写真(前・選択中・次)

    private var photoStrip: some View {
        let index = selectedIndex
        let previous = index.flatMap { missions[safe: $0 - 1] }
        let next = index.flatMap { missions[safe: $0 + 1] }
        let current = index.flatMap { missions[safe: $0] }
        return HStack(alignment: .center, spacing: 12) {
            sidePhoto(previous)
            VStack(spacing: 6) {
                polaroid(current, width: 140, height: 92, border: 4)
                Text(current.map { "MISSION \($0.order)" } ?? "MISSION")
                    .font(.handNumber(16))
                    .foregroundStyle(Color.appAccent)
            }
            sidePhoto(next)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomTrailing) {
            // 自分のアバター(ゴールピンの上)
            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .padding(3)
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
                .overlay(Circle().stroke(Color.appAccent, lineWidth: 1))
                .padding(.trailing, 4)
        }
        .animation(.snappy, value: selectedMissionId)
    }

    private func sidePhoto(_ mission: Mission?) -> some View {
        Button {
            if let mission { selectedMissionId = mission.id }
        } label: {
            polaroid(mission, width: 82, height: 54, border: 3)
                .opacity(mission == nil ? 0.25 : 0.85)
        }
        .buttonStyle(.plain)
        .disabled(mission == nil)
        .padding(.bottom, 22)
    }

    @ViewBuilder
    private func polaroid(_ mission: Mission?, width: CGFloat, height: CGFloat, border: CGFloat) -> some View {
        Group {
            if let mission, let image = photo(mission) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray4)
                    .overlay {
                        if let mission {
                            Image(systemName: mission.category.symbolName)
                                .foregroundStyle(Color.inkSub)
                        }
                    }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .border(.white, width: border)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    // MARK: - 時間軸

    private var timelineAxis: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let inset: CGFloat = 20
            let usable = max(0, width - inset * 2)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appAccent)
                    .frame(height: 2)
                    .frame(maxHeight: .infinity)
                // ゴール(右端)
                Image("PinSmall2")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .overlay {
                        Image("PinHeart")
                            .resizable()
                            .frame(width: 9, height: 8)
                            .offset(y: -1)
                    }
                    .position(x: inset + usable, y: geometry.size.height / 2)
                ForEach(timeline.markers) { marker in
                    let isSelected = marker.missionId == selectedMissionId
                    Button {
                        selectedMissionId = marker.missionId
                    } label: {
                        Image(isSelected ? "PinLarge" : "PinSmall")
                            .resizable()
                            .frame(width: isSelected ? 25 : 16, height: isSelected ? 25 : 16)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // ゴールピンと重ならないよう 0.94 までに収める
                    .position(x: inset + marker.position * usable * 0.94, y: geometry.size.height / 2)
                }
            }
        }
        .frame(height: 32)
        .animation(.snappy, value: selectedMissionId)
    }

    // MARK: - 心拍バー(ドキドキ ログ)

    private var heartLog: some View {
        let selectedBar = selectedMarker?.barIndex
        let peak = timeline.peakBar?.index
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(timeline.bars) { bar in
                let isSelected = bar.index == selectedBar
                let isPeak = bar.index == peak && timeline.hasSamples
                Button {
                    if let nearest = timeline.marker(nearestTo: bar.index) {
                        selectedMissionId = nearest.missionId
                    }
                } label: {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(isSelected: isSelected, isPeak: isPeak))
                            .frame(height: max(6, 64 * bar.level))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .overlay {
                        if isSelected {
                            // 選択区間のカーソル
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray4))
                                .frame(width: 7)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 76)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.98, green: 0.97, blue: 0.94))
        .animation(.snappy, value: selectedMissionId)
    }

    private func barColor(isSelected: Bool, isPeak: Bool) -> Color {
        let hot = Color(red: 0.98, green: 0.43, blue: 0.33)
        if isSelected { return hot }
        if isPeak { return hot.opacity(0.75) }
        return hot.opacity(0.28)
    }

    private var dashedSeparator: some View {
        Rectangle()
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .padding(.horizontal, 6)
            .padding(.top, 6)
    }
}
