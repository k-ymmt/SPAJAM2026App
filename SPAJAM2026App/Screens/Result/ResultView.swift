//
//  ResultView.swift
//  SPAJAM2026App
//
//  05 リザルト「ふりかえり」。コアバリュー(見なかったから結果に繋がる)を 1 画面で語る:
//  共通ミッションの写真 → ひとこと → 写真タイムライン → ドキドキログ(心拍) →
//  「スマホを見なかった◯時間のあいだに心が動いた瞬間が◯回」→ 3 指標 → 旅のハイライト。
//  デザイン: 2 日目確定モック(浅草まったり旅 ふりかえり)
//

import SwiftUI

struct ResultView: View {
    @Environment(TripSession.self) private var session
    var onRestart: () -> Void

    @State private var selectedPhotoIndex = 0
    @State private var isSuggestionPickerPresented = false
    @State private var highlightImageURL: URL?

    /// ドキドキログの配色
    private let pulseSoft = Color(red: 0.972, green: 0.792, blue: 0.749)
    private let pulsePeak = Color(red: 0.949, green: 0.353, blue: 0.235)
    private let pulseBackground = Color(red: 0.988, green: 0.933, blue: 0.914)

    var body: some View {
        VStack(spacing: 0) {
            headerBand
            ScrollView {
                VStack(spacing: 18) {
                    sharedMissionPhoto
                    summaryLine
                    photoTimeline
                    pulseLog
                    causalityLine
                    statCards
                    highlightSection
                    buttons
                }
                .padding(24)
            }
        }
        .background(Color.appBackground)
        .suggestionPicker(isPresented: $isSuggestionPickerPresented) { entry in
            highlightImageURL = entry.items.compactMap(\.imageURL).first
        }
    }

    // MARK: - ヘッダーバンド

    private var headerBand: some View {
        Text("\(session.plan.title) ふりかえり")
            .font(.handTitle)
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.7), radius: 0.5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appAccent)
    }

    // MARK: - 共通ミッションの写真

    /// 共通ミッションの記録写真(なければ最初の記録写真)
    private var sharedPhoto: UIImage? {
        let sharedIds = Set(session.plan.missions.filter { $0.isShared == true }.map(\.id))
        let record = session.records.first { sharedIds.contains($0.missionId) } ?? session.records.first
        return record.flatMap { session.photo(for: $0) }
    }

    @ViewBuilder
    private var sharedMissionPhoto: some View {
        Group {
            if let photo = sharedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray4)
                    .overlay {
                        Image("MizaruCharacter")
                            .resizable()
                            .scaledToFit()
                            .padding(30)
                            .opacity(0.7)
                    }
            }
        }
        .frame(width: 300, height: 210)
        .clipped()
        .padding(8)
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .rotationEffect(.degrees(-2.5))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    /// ひとことまとめ
    private var summaryLine: some View {
        let party = session.plan.partySize ?? 1
        let text = party >= 2
            ? "\(party)人でいろんなことをした\nいい旅だったみたい"
            : "じぶんのペースでたのしむ\nいい旅だったみたい"
        return Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.inkMain)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 写真タイムライン

    /// 写真つきの達成記録(ミッション順)
    private var photoRecords: [(mission: Mission, image: UIImage)] {
        session.plan.missions.compactMap { mission in
            guard let record = session.records.first(where: { $0.missionId == mission.id }),
                  let image = session.photo(for: record) else { return nil }
            return (mission, image)
        }
    }

    @ViewBuilder
    private var photoTimeline: some View {
        let records = photoRecords
        if !records.isEmpty {
            VStack(spacing: 10) {
                TabView(selection: $selectedPhotoIndex) {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, item in
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 170)
                            .clipped()
                            .padding(6)
                            .background(.white)
                            .padding(.horizontal, 40)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 190)

                Text("MISSION \(records[safe: selectedPhotoIndex]?.mission.order ?? 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.appAccent)

                timelineBar(count: records.count)
            }
        }
    }

    /// ピン+ハートのタイムライン(選択中のピンが大きくなる)
    private func timelineBar(count: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { i in
                let selected = i == selectedPhotoIndex
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: selected ? 24 : 16))
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .onTapGesture { withAnimation { selectedPhotoIndex = i } }
            }
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(pulsePeak)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .center) {
            Capsule().fill(Color.appAccent).frame(height: 3)
        }
    }

    // MARK: - ドキドキログ

    /// 心拍を 9 区間の平均 bpm に集計(0...1 正規化と生値)。サンプル不足はダミー波形
    private var pulseBars: [(level: Double, bpm: Double)] {
        let samples = session.heartRateSamples.map(\.bpm)
        guard samples.count >= 9 else {
            return [0.3, 0.4, 0.35, 0.55, 0.45, 0.65, 0.85, 1.0, 0.5].map { ($0, 60 + $0 * 40) }
        }
        let chunk = max(1, samples.count / 9)
        let buckets: [Double] = (0..<9).map { i in
            let slice = samples.dropFirst(i * chunk).prefix(chunk)
            return slice.isEmpty ? 0 : slice.reduce(0, +) / Double(slice.count)
        }
        let lo = (buckets.min() ?? 60) - 4
        let hi = max((buckets.max() ?? 100), lo + 8)
        return buckets.map { (max(0.12, ($0 - lo) / (hi - lo)), $0) }
    }

    private var pulseLog: some View {
        let bars = pulseBars
        let peakIndex = bars.indices.max(by: { bars[$0].level < bars[$1].level }) ?? 0
        let average = bars.map(\.bpm).reduce(0, +) / Double(max(1, bars.count))
        let peakDelta = Int((bars[safe: peakIndex]?.bpm ?? average) - average)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ドキドキ ログ")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.inkMain)
                Spacer()
                Text("ピーク +\(max(0, peakDelta))bpm")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(pulsePeak)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, bar in
                    RoundedRectangle(cornerRadius: 5)
                        .fill(index == peakIndex ? pulsePeak : pulseSoft)
                        .frame(height: 24 + 66 * bar.level)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(pulseBackground, in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 因果の一文(コアバリュー)

    private var offlineText: String {
        let minutes = Int(session.offlineDuration / 60)
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(minutes)分"
    }

    /// 心が動いた瞬間の回数(平均+15bpm を超えた山を 3 分間隔で数える)
    private var heartMovedCount: Int {
        let samples = session.heartRateSamples
        guard samples.count >= 5 else { return max(1, session.records.count) }
        let average = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
        var count = 0
        var lastAt: Date?
        for sample in samples where sample.bpm >= average + 15 {
            if let last = lastAt, sample.date.timeIntervalSince(last) < 180 { continue }
            count += 1
            lastAt = sample.date
        }
        return max(count, 1)
    }

    private var causalityLine: some View {
        Text("スマホを見なかった \(offlineText) のあいだに\n心が動いた瞬間が \(heartMovedCount)回 ありました")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.inkMain)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - 3 指標

    private var maxBPMText: String {
        session.heartRateSamples.map(\.bpm).max().map { "\(Int($0))bpm" } ?? "--"
    }

    private var statCards: some View {
        HStack(spacing: 10) {
            statCard(title: "目の前に夢中", value: "オフライン：\(offlineText)")
            statCard(title: "いろいろチャレンジ", value: "ミッション達成数：\(session.records.count)")
            statCard(title: "心が動いた", value: "最高心拍：\(maxBPMText)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Text(value)
                .font(.system(size: 11))
        }
        .foregroundStyle(Color.inkMain)
        .multilineTextAlignment(.center)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appAccent, lineWidth: 1.5))
    }

    // MARK: - 旅のハイライト(Journaling Suggestions)

    private var highlightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("旅のハイライト")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.inkMain)

            Button {
                isSuggestionPickerPresented = true
            } label: {
                Group {
                    if let highlightImageURL {
                        AsyncImage(url: highlightImageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 28))
                            Text("タップして旅の思い出をえらぶ")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(Color.inkSub)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - ボタン

    private var buttons: some View {
        VStack(spacing: 10) {
            ShareLink(item: "『\(session.plan.title)』を旅してきました! スマホを見なかった\(offlineText)のあいだに心が動いた瞬間が\(heartMovedCount)回 #ミザル") {
                Text("結果をシェアする")
                    .font(.handHeadline)
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.8), radius: 0.5)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        Image("BrushButton")
                            .resizable(resizingMode: .stretch)
                    }
            }
            OutlineButton(label: "もう一回たびする", action: onRestart)
        }
        .padding(.top, 4)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
