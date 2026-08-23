//
//  HeartRateTimelineView.swift
//  SPAJAM2026App
//
//  リザルトの「心拍が上がったミッションのピン ↔ 心拍の折れ線グラフ」ビュー(Figma 旅後/結果画面 ver3)。
//  中段の緑のラインを旅の時間の数直線に見立て、ピンを達成時刻の位置に置く
//    - 自分の最高心拍に近いミッション: 大きいピン + 大きい写真 + 「MISSION X」
//    - 他の参加者の最高心拍に近いミッション: ハート型ピン + 上に参加者アイコン + 小さい写真
//    - 参加者が 2 人以下のときだけ、自分の 2 番目に高かったミッション: 小さいピン + 小さい写真
//  下段: 時間帯ごとの最大心拍を結ぶ折れ線グラフ(Figma 旅後/結果画面_最大心拍ゲージ時 node 230:12339)。
//  緑の縦棒カーソルは左右にドラッグでき、指している旅の時刻を `onCursorTimeChange` で通知する。
//  初期位置は自分の最高心拍ミッションの達成時刻。
//

import SwiftUI

struct HeartRateTimelineView: View {
    let timeline: HeartRateTimeline
    /// 時間順のピン(`HeartRateTimeline.pins`)
    let pins: [HeartRateTimeline.Pin]
    /// プランのミッション(写真・番号の解決用)
    let missions: [Mission]
    let photo: (Mission) -> UIImage?
    /// グラフのカーソルを動かしたときに、カーソルが指す旅の時刻を受け取る
    var onCursorTimeChange: (Date) -> Void = { _ in }

    /// ドラッグで動かしたカーソル位置(0...1)。nil なら初期位置(自分の最高心拍ミッション)
    @State private var draggedCursorPosition: Double?

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

    private enum Chart {
        /// グラフ全体の高さ(Figma: 93pt)
        static let height: CGFloat = 93
        /// 折れ線の上下余白(Figma: 線の範囲は 22pt〜78pt)
        static let lineTopInset: CGFloat = 22
        static let lineBottomInset: CGFloat = 15
        static let lineWidth: CGFloat = 4
        /// 太い方のカーソルの高さ
        static let thickCursorHeight: CGFloat = 62
        /// Figma green3
        static let line = Color(red: 0.553, green: 0.804, blue: 0.773)
        static let gradientTop = Color(red: 0.945, green: 0.945, blue: 0.945).opacity(0)
        static let gradientBottom = Color(red: 0.855, green: 0.667, blue: 0.149).opacity(0.15)
    }

    var body: some View {
        VStack(spacing: 0) {
            pinArea
            heartLog
            separator
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

    // MARK: - 心拍の折れ線グラフ(ドキドキ ログ)

    /// カーソル位置(0...1)。nil なら自分の最高心拍ミッション(無ければピーク区間)に置く
    private var cursorPosition: Double {
        if let draggedCursorPosition { return draggedCursorPosition }
        if let main = pins.first(where: \.isMain) { return main.position }
        if let peak = timeline.peakBar, timeline.hasSamples { return pointPosition(peak.index) }
        return 0.5
    }

    /// 折れ線の `index` 番目の点の横位置(0...1)。両端の点をグラフの端に置く
    private func pointPosition(_ index: Int) -> Double {
        let count = timeline.bars.count
        return count > 1 ? Double(index) / Double(count - 1) : 0.5
    }

    private var heartLog: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cursorX = CGFloat(cursorPosition) * width
            ZStack(alignment: .topLeading) {
                linePath(width: width)
                    .stroke(Chart.line, style: StrokeStyle(lineWidth: Chart.lineWidth, lineCap: .round, lineJoin: .round))
                // カーソル: 細い線(全高)+ 太い線(中央)
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: 2, height: Chart.height)
                    .position(x: cursorX, y: Chart.height / 2)
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: 4, height: Chart.thickCursorHeight)
                    .position(x: cursorX, y: Chart.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let position = Double(min(width, max(0, value.location.x)) / max(width, 1))
                        draggedCursorPosition = position
                        onCursorTimeChange(timeline.date(at: position))
                    }
            )
        }
        .frame(height: Chart.height)
        .background(
            LinearGradient(
                colors: [Chart.gradientTop, Chart.gradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .padding(.horizontal, Metrics.inset)
        .accessibilityElement()
        .accessibilityLabel("心拍の推移")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// 区間ごとの最大心拍を結ぶ折れ線。level 1 が上端、0 が下端
    private func linePath(width: CGFloat) -> Path {
        let bars = timeline.bars
        guard !bars.isEmpty else { return Path() }
        let usableHeight = Chart.height - Chart.lineTopInset - Chart.lineBottomInset
        let points = bars.map { bar in
            CGPoint(
                x: CGFloat(pointPosition(bar.index)) * width,
                y: Chart.lineTopInset + (1 - CGFloat(bar.level)) * usableHeight
            )
        }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private var separator: some View {
        Rectangle()
            .fill(Chart.line)
            .frame(height: 2)
            .padding(.horizontal, Metrics.inset)
    }
}
