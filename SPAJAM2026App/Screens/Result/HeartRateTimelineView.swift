//
//  HeartRateTimelineView.swift
//  SPAJAM2026App
//
//  リザルトの「思い出カルーセル ↔ 心拍の折れ線グラフ」ビュー。
//  上段: 自分のミッション写真とみんなの「心が動いた瞬間」の写真を時系列(古い順)に横スクロール。
//        ページング(viewAligned)で、真ん中の写真が大きくなる。末尾の次は先頭に戻る無限スクロール。
//        写真の下はミッションなら「MISSION n」、心が動いた瞬間なら 撮った人のアイコン + 「心が動いた瞬間」。
//  中段: 旅の時間を表す緑の横ライン(Figma node 230:12468)。項目の時刻の位置にピン(ミッション)/ハート(心が動いた瞬間)を置く。
//  下段: 時間帯ごとの最大心拍を結ぶ折れ線グラフ(Figma 旅後/結果画面_最大心拍ゲージ時 node 230:12339)。
//  連動: カルーセルを動かすと緑の縦棒カーソルが追従して項目の時刻で止まる。
//        カーソルをドラッグすると項目の位置で引っかかり(スナップ)、カルーセルもその項目へ移動する。
//        引っかかった(選択が変わった)ときは Haptic Feedback。
//

import SwiftUI

struct HeartRateTimelineView: View {
    let timeline: HeartRateTimeline
    /// 時系列順の項目(`MemoryEntry.build`)
    let entries: [MemoryEntry]
    /// 項目の写真。スクロール中に毎フレーム呼ばれるので、縮小済みのキャッシュを返すこと(MemoryThumbnailCache)
    let photo: (MemoryEntry) -> UIImage?

    /// 中央の写真の表示サイズ(サムネイル生成の基準)
    static var photoSize: CGSize { Carousel.centerPhoto }
    /// カーソルが指す旅の時刻が変わったときに受け取る
    var onCursorTimeChange: (Date) -> Void = { _ in }

    /// 選択中(中央)の項目 id。Haptic のトリガにも使う
    @State private var selectedEntryId: String?
    /// カルーセルの scrollPosition 用(コピーを区別した仮想 id)
    @State private var scrollItemId: String?
    /// カーソル位置(0...1)
    @State private var cursorPosition: Double = 0

    init(
        timeline: HeartRateTimeline,
        entries: [MemoryEntry],
        photo: @escaping (MemoryEntry) -> UIImage?,
        onCursorTimeChange: @escaping (Date) -> Void = { _ in }
    ) {
        self.timeline = timeline
        self.entries = entries
        self.photo = photo
        self.onCursorTimeChange = onCursorTimeChange
        // 初期選択は一番古い項目。スクロール位置はレイアウト確定後に合わせる(scrollGeometry を見て 1 回だけ)
        if let first = entries.first {
            _selectedEntryId = State(initialValue: first.id)
            _cursorPosition = State(initialValue: first.position)
        }
    }
    /// グラフをドラッグ中はカルーセルからの連動を止める
    @State private var isDraggingChart = false
    @State private var isScrolling = false
    /// 初回レイアウト後に真ん中のコピーへジャンプ済みか
    @State private var hasPositioned = false

    /// スクロール量から求める、中央に来ている連続的な項目 index と、レイアウト確定判定用のコンテンツ幅
    private struct CarouselGeometry: Equatable {
        var fractionalIndex: Double
        var contentWidth: CGFloat
    }

    private enum Carousel {
        static let height: CGFloat = 196
        static let centerPhoto = CGSize(width: 168, height: 112)
        /// 両隣の写真の縮小率
        static let sideScale: CGFloat = 0.7
        static let spacing: CGFloat = 8
        static let labelHeight: CGFloat = 28
        /// 1 項目の幅(縮小した隣の写真が見える程度に詰める)
        static var itemWidth: CGFloat { centerPhoto.width * 0.86 }
    }

    private enum Axis {
        /// ライン+アイコンの高さ(Figma: 25pt)
        static let height: CGFloat = 25
        static let lineWidth: CGFloat = 2
        static let selectedIcon: CGFloat = 25
        static let icon: CGFloat = 16
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
        /// 左右余白(Figma: 402pt 中 23pt)
        static let inset: CGFloat = 23
        /// カーソルが項目に引っかかる距離(pt)
        static let snapRadius: CGFloat = 14
        /// Figma green3
        static let line = Color(red: 0.553, green: 0.804, blue: 0.773)
        static let gradientTop = Color(red: 0.945, green: 0.945, blue: 0.945).opacity(0)
        static let gradientBottom = Color(red: 0.855, green: 0.667, blue: 0.149).opacity(0.15)
    }

    /// 無限スクロール用に項目を何周分並べるか(少ないときは多めに)
    private static func repeatCount(for count: Int) -> Int {
        switch count {
        case 0: 0
        case 1: 1
        case 2: 5
        default: 3
        }
    }

    private var repeatCount: Int { Self.repeatCount(for: entries.count) }

    private var middleCopy: Int { repeatCount / 2 }

    /// 仮想 id = "コピー番号|項目 id"
    private static func itemId(copy: Int, entryId: String) -> String { "\(copy)|\(entryId)" }

    private func itemId(copy: Int, entry: MemoryEntry) -> String { Self.itemId(copy: copy, entryId: entry.id) }

    private func entryId(fromItemId itemId: String) -> String? {
        itemId.split(separator: "|", maxSplits: 1).last.map(String.init)
    }

    private func entry(for id: String?) -> MemoryEntry? {
        entries.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            carousel
            markerAxis
                .padding(.top, 8)
                .padding(.bottom, 2)
            heartLog
            separator
        }
        .sensoryFeedback(.selection, trigger: selectedEntryId) { old, new in old != nil && new != nil && old != new }
        .onAppear {
            if let entry = entry(for: selectedEntryId) { onCursorTimeChange(entry.date) }
        }
        .onChange(of: entries) { _, new in
            // 他の参加者の写真が届くなどで項目が変わったら、選択を保ったまま位置を取り直す
            guard let selected = entry(for: selectedEntryId) ?? new.first else { return }
            scrollItemId = itemId(copy: middleCopy, entry: selected)
            select(selected, scrollCarousel: false)
        }
    }

    // MARK: - 選択

    /// 項目を選ぶ。カーソルをその時刻に置き(`moveCursor`)、必要ならカルーセルもそこへ寄せる
    private func select(_ entry: MemoryEntry, scrollCarousel: Bool, moveCursor: Bool = true) {
        selectedEntryId = entry.id
        if moveCursor {
            withAnimation(.snappy(duration: 0.25)) { cursorPosition = entry.position }
        }
        onCursorTimeChange(entry.date)
        if scrollCarousel {
            withAnimation(.snappy(duration: 0.3)) {
                scrollItemId = itemId(copy: middleCopy, entry: entry)
            }
        }
    }

    // MARK: - 思い出カルーセル

    private var carousel: some View {
        // 幅は同じレイアウト内で取る(後から変わると初期スクロール位置がずれる)
        GeometryReader { geometry in
            carouselScroll(width: geometry.size.width)
        }
        .frame(height: Carousel.height)
        .accessibilityLabel("旅の思い出")
    }

    private func carouselScroll(width: CGFloat) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Carousel.spacing) {
                ForEach(0..<repeatCount, id: \.self) { copy in
                    ForEach(entries) { entry in
                        carouselItem(entry)
                            .id(itemId(copy: copy, entry: entry))
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $scrollItemId, anchor: .center)
        .safeAreaPadding(.horizontal, max(0, (width - Carousel.itemWidth) / 2))
        .onScrollGeometryChange(for: CarouselGeometry.self) { geometry in
            // 中央に来ている連続的な項目 index(コピーをまたいだ通し番号)
            let step = Carousel.itemWidth + Carousel.spacing
            return CarouselGeometry(
                fractionalIndex: (geometry.contentOffset.x + geometry.contentInsets.leading) / step,
                contentWidth: geometry.contentSize.width
            )
        } action: { _, geometry in
            if !hasPositioned, geometry.contentWidth > 0, let entry = entry(for: selectedEntryId) {
                // レイアウトが確定したら真ん中のコピーの選択項目へ瞬時にジャンプ(左にも古い項目が並ぶようにする)
                hasPositioned = true
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { scrollItemId = itemId(copy: middleCopy, entry: entry) }
                return
            }
            guard !isDraggingChart, isScrolling, !entries.isEmpty else { return }
            cursorPosition = entries.position(atFractionalIndex: geometry.fractionalIndex)
        }
        .onScrollPhaseChange { _, phase in
            isScrolling = phase != .idle
            if phase == .idle { settleCarousel() }
        }
        .onChange(of: scrollItemId) { _, new in
            guard let new, let entry = entry(for: entryId(fromItemId: new)), entry.id != selectedEntryId else { return }
            // 指で動かしている間はカーソルはスクロール量に追従させ、止まったら settleCarousel で時刻に合わせる
            select(entry, scrollCarousel: false, moveCursor: !isScrolling)
        }
    }

    /// スクロールが止まったら、カーソルを項目の時刻にぴったり合わせ、端のコピーにいたら真ん中のコピーに巻き戻す
    private func settleCarousel() {
        guard let scrollItemId, let entry = entry(for: entryId(fromItemId: scrollItemId)) else { return }
        if entry.id == selectedEntryId {
            withAnimation(.snappy(duration: 0.2)) { cursorPosition = entry.position }
        } else {
            select(entry, scrollCarousel: false)
        }
        let copy = Int(scrollItemId.split(separator: "|").first ?? "") ?? middleCopy
        guard copy != middleCopy else { return }
        // 端のコピーから真ん中のコピーへ瞬時に巻き戻す(見た目は同じ項目なので気づかれない)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.scrollItemId = itemId(copy: middleCopy, entry: entry)
        }
    }

    private func carouselItem(_ entry: MemoryEntry) -> some View {
        VStack(spacing: 6) {
            polaroid(entry)
            caption(entry)
                .frame(height: Carousel.labelHeight)
        }
        .frame(width: Carousel.itemWidth)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .scaleEffect(1 - (1 - Carousel.sideScale) * min(1, abs(phase.value)))
                .opacity(1 - 0.25 * min(1, abs(phase.value)))
        }
        .onTapGesture { select(entry, scrollCarousel: true) }
    }

    @ViewBuilder
    private func caption(_ entry: MemoryEntry) -> some View {
        switch entry.kind {
        case .mission:
            Text(entry.label)
                .font(.handNumber(16))
                .foregroundStyle(Color.appAccent)
        case .heart(let owner):
            HStack(spacing: 6) {
                avatar(name: owner)
                Text(entry.label)
                    .font(.handCaption2.bold())
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    /// 撮った人のアイコン(名前の頭文字。自分は人型)
    private func avatar(name: String?) -> some View {
        Group {
            if let name, let initial = name.first {
                Text(String(initial))
                    .font(.handNumber(12))
                    .foregroundStyle(Color.appAccent)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .background(name == nil ? Color.appAccent : .white, in: Circle())
        .overlay(Circle().stroke(Color.appAccent, lineWidth: 1))
    }

    private func polaroid(_ entry: MemoryEntry) -> some View {
        Group {
            if let image = photo(entry) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray4)
                    .overlay {
                        Image(systemName: entry.isMission ? "camera" : "heart")
                            .foregroundStyle(Color.inkSub)
                    }
            }
        }
        .frame(width: Carousel.centerPhoto.width, height: Carousel.centerPhoto.height)
        .clipped()
        .border(.white, width: 4)
        .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
    }

    // MARK: - 時間軸のライン + ピン/ハート

    /// 旅の時間を表す横ライン。項目の時刻の位置にアイコンを置き、選択中は大きくする。タップで選べる
    private var markerAxis: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.appAccent)
                    .frame(width: width, height: Axis.lineWidth)
                    .position(x: width / 2, y: Axis.height / 2)
                ForEach(entries) { entry in
                    let isSelected = entry.id == selectedEntryId
                    markerIcon(entry, isSelected: isSelected)
                        .position(x: CGFloat(entry.position) * width, y: Axis.height / 2)
                        .zIndex(isSelected ? 1 : 0)
                        .onTapGesture { select(entry, scrollCarousel: true) }
                }
            }
        }
        .frame(height: Axis.height)
        .padding(.horizontal, Chart.inset)
    }

    @ViewBuilder
    private func markerIcon(_ entry: MemoryEntry, isSelected: Bool) -> some View {
        let size = isSelected ? Axis.selectedIcon : Axis.icon
        if entry.isMission {
            Image(isSelected ? "PinLarge" : "PinSmall")
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image("PinSmall2")
                .resizable()
                .frame(width: size, height: size)
                .overlay {
                    Image("PinHeart")
                        .resizable()
                        .frame(width: size * 0.56, height: size * 0.5)
                        .offset(y: -size * 0.06)
                }
        }
    }

    // MARK: - 心拍の折れ線グラフ(ドキドキ ログ)

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
                        isDraggingChart = true
                        dragCursor(toX: value.location.x, width: width, settle: false)
                    }
                    .onEnded { value in
                        dragCursor(toX: value.location.x, width: width, settle: true)
                        isDraggingChart = false
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
        .padding(.horizontal, Chart.inset)
        .accessibilityElement()
        .accessibilityLabel("心拍の推移")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    /// カーソルを x へ動かす。項目の近くなら引っかけ(スナップ)、指を離したら最寄りの項目に寄せる
    private func dragCursor(toX x: CGFloat, width: CGFloat, settle: Bool) {
        let raw = Double(min(width, max(0, x)) / max(width, 1))
        let radius = Double(Chart.snapRadius / max(width, 1))
        let target = settle ? entries.nearest(to: raw) : entries.snapTarget(for: raw, radius: radius)
        if let target {
            if target.id != selectedEntryId {
                select(target, scrollCarousel: true)
            } else if settle {
                withAnimation(.snappy(duration: 0.2)) { cursorPosition = target.position }
            } else {
                cursorPosition = target.position
            }
        } else {
            cursorPosition = raw
            onCursorTimeChange(timeline.date(at: raw))
        }
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
            .padding(.horizontal, Chart.inset)
    }
}
