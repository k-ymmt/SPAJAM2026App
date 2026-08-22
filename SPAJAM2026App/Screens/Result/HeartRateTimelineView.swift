//
//  HeartRateTimelineView.swift
//  SPAJAM2026App
//
//  リザルトの「心拍が上がったミッションのピン ↔ 心拍バー」ビュー(Figma 旅後/結果画面 ver3)。
//  中段の緑のラインを旅の時間の数直線に見立て、ピンを達成時刻の位置に置く
//    - 自分の最高心拍に近いミッション: 大きいピン + 大きい写真 + 「MISSION X」
//    - 他の参加者の最高心拍に近いミッション: ハート型ピン + 上に参加者アイコン + 小さい写真
//    - 参加者が 2 人以下のときだけ、自分の 2 番目に高かったミッション: 小さいピン + 小さい写真
//  下段: 時間帯ごとの心拍バー(クリーム帯)。自分の最高心拍ミッションの区間をグレーのカーソルで示し、ピークを強調
//  タップ操作は無し(心拍は自分の分だけ)。
//

import SwiftUI

struct HeartRateTimelineView: View {
    let timeline: HeartRateTimeline
    /// 時間順のピン(`HeartRateTimeline.pins`)
    let pins: [HeartRateTimeline.Pin]
    /// プランのミッション(写真・番号の解決用)
    let missions: [Mission]
    let photo: (Mission) -> UIImage?

    private enum Metrics {
        /// ピン/写真エリアの高さ
        static let height: CGFloat = 152
        /// ラインの中心 y
        static let axisY: CGFloat = 136
        /// ラインの左右余白(Figma: 402pt 中 23pt)
        static let inset: CGFloat = 23
        static let mainPhoto = CGSize(width: 140, height: 92)
        static let smallPhoto = CGSize(width: 82, height: 54)
        /// 写真の下端からラインまでの距離
        static let mainPhotoGap: CGFloat = 42
        static let smallPhotoGap: CGFloat = 60
    }

    var body: some View {
        VStack(spacing: 10) {
            pinArea
            heartLog
            dashedSeparator
        }
    }

    private func mission(for pin: HeartRateTimeline.Pin) -> Mission? {
        missions.first { $0.id == pin.missionId }
    }

    // MARK: - ピン + 写真

    private var pinArea: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let usable = max(0, width - Metrics.inset * 2)
            let pinX = pins.map { Metrics.inset + CGFloat($0.position) * usable }
            let photoX = photoCenters(pinX: pinX, width: width)
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: usable, height: 2)
                    .position(x: width / 2, y: Metrics.axisY)
                // 小さい写真 → 大きい写真の順に重ねる(大きい方を前に)
                ForEach(Array(pins.enumerated()), id: \.element.id) { index, pin in
                    pinView(pin)
                        .position(x: pinX[index], y: Metrics.axisY)
                    photoView(pin)
                        .position(x: photoX[index], y: photoCenterY(pin))
                        .zIndex(pin.isMain ? 2 : 1)
                    if case .other(let name) = pin.kind {
                        avatar(name: name)
                            .position(x: pinX[index], y: Metrics.axisY - 30)
                            .zIndex(3)
                    }
                }
            }
        }
        .frame(height: Metrics.height)
    }

    private func photoCenterY(_ pin: HeartRateTimeline.Pin) -> CGFloat {
        pin.isMain
            ? Metrics.axisY - Metrics.mainPhotoGap - Metrics.mainPhoto.height / 2
            : Metrics.axisY - Metrics.smallPhotoGap - Metrics.smallPhoto.height / 2
    }

    /// 写真の中心 x。ピンの真上を基本に、画面からはみ出さないよう寄せ、大きい写真と重なる小さい写真は横に逃がす
    private func photoCenters(pinX: [CGFloat], width: CGFloat) -> [CGFloat] {
        func clamp(_ x: CGFloat, size: CGSize) -> CGFloat {
            min(width - size.width / 2 - 4, max(size.width / 2 + 4, x))
        }
        let mainIndex = pins.firstIndex(where: \.isMain)
        let mainX = mainIndex.map { clamp(pinX[$0], size: Metrics.mainPhoto) }
        let minDistance = (Metrics.mainPhoto.width + Metrics.smallPhoto.width) / 2 + 8
        return pins.indices.map { index in
            if index == mainIndex { return mainX ?? pinX[index] }
            var x = pinX[index]
            if let mainX, abs(x - mainX) < minDistance {
                x = x < mainX ? mainX - minDistance : mainX + minDistance
            }
            return clamp(x, size: Metrics.smallPhoto)
        }
    }

    @ViewBuilder
    private func pinView(_ pin: HeartRateTimeline.Pin) -> some View {
        switch pin.kind {
        case .main:
            Image("PinLarge")
                .resizable()
                .frame(width: 25, height: 25)
        case .second:
            Image("PinSmall")
                .resizable()
                .frame(width: 16, height: 16)
        case .other:
            Image("PinSmall2")
                .resizable()
                .frame(width: 16, height: 16)
                .overlay {
                    Image("PinHeart")
                        .resizable()
                        .frame(width: 9, height: 8)
                        .offset(y: -1)
                }
        }
    }

    @ViewBuilder
    private func photoView(_ pin: HeartRateTimeline.Pin) -> some View {
        let mission = mission(for: pin)
        if pin.isMain {
            VStack(spacing: 6) {
                polaroid(mission, size: Metrics.mainPhoto, border: 4)
                Text(mission.map { "MISSION \($0.order)" } ?? "MISSION")
                    .font(.handNumber(16))
                    .foregroundStyle(Color.appAccent)
                    .fixedSize()
            }
            // VStack 全体ではなく写真の中心が position に来るよう、ラベル分を下にずらす
            .offset(y: (6 + 16) / 2)
        } else {
            polaroid(mission, size: Metrics.smallPhoto, border: 3)
        }
    }

    /// 他の参加者のアイコン(名前の頭文字)
    private func avatar(name: String) -> some View {
        Text(String(name.prefix(1)))
            .font(.handNumber(13))
            .foregroundStyle(Color.appAccent)
            .frame(width: 28, height: 28)
            .background(.white, in: Circle())
            .overlay(Circle().stroke(Color.appAccent, lineWidth: 1))
    }

    @ViewBuilder
    private func polaroid(_ mission: Mission?, size: CGSize, border: CGFloat) -> some View {
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
        .frame(width: size.width, height: size.height)
        .clipped()
        .border(.white, width: border)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    // MARK: - 心拍バー(ドキドキ ログ)

    private var heartLog: some View {
        let mainBar = pins.first(where: \.isMain)?.barIndex
        let peak = timeline.peakBar?.index
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(timeline.bars) { bar in
                let isMain = bar.index == mainBar
                let isPeak = bar.index == peak && timeline.hasSamples
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor(isMain: isMain, isPeak: isPeak))
                        .frame(height: max(6, 64 * bar.level))
                }
                .frame(maxWidth: .infinity)
                .overlay {
                    if isMain {
                        // 自分の最高心拍ミッションの区間カーソル
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(.systemGray4))
                            .frame(width: 7)
                    }
                }
            }
        }
        .frame(height: 76)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.98, green: 0.97, blue: 0.94))
    }

    private func barColor(isMain: Bool, isPeak: Bool) -> Color {
        let hot = Color(red: 0.98, green: 0.43, blue: 0.33)
        if isMain { return hot }
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
