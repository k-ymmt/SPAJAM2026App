//
//  ResultView.swift
//  SPAJAM2026App
//
//  05 リザルト(旅後/結果画面 ver2)。
//  緑帯のタイトル → ガーランド飾り+共通ミッションの写真+ミザル → ミッション写真と同期した自分の心拍バー
//  → まとめの一文 → 3 つの指標(手描きフレーム)→ 旅のハイライト(Journaling Suggestions)→ シェア。
//  複数人の旅(membership あり)は rooms/{code}/results を購読し、全員が終わるまで待機表示にする。
//  デザイン: Figma SPAJAM2026「旅後/結果画面ver2」(node 208:9060)。手描き素材は Assets/Result に書き出し済み
//

import SwiftUI

struct ResultView: View {
    @Environment(TripSession.self) private var session
    var onRestart: () -> Void

    @State private var observer = TripRoomObserver()
    @State private var selectedMissionId: String?

    private var isShared: Bool { session.membership != nil }

    /// 複数人の旅で、まだ終わっていない人がいる
    private var isWaitingForOthers: Bool { isShared && !observer.isAllFinished }

    /// 達成したミッションを達成順に
    private var achievedMissions: [Mission] {
        session.records
            .sorted { $0.achievedAt < $1.achievedAt }
            .compactMap { record in session.plan.missions.first { $0.id == record.missionId } }
    }

    /// 自分の心拍だけで組み立てる時間軸。サンプルが無ければデモ波形
    private var timeline: HeartRateTimeline {
        let interval = session.tripInterval
        var samples = session.heartRateSamples
        if samples.count < 3 {
            let demoInterval = interval ?? HeartRateTimeline(samples: [], records: session.records, interval: nil).interval
            samples = HeartRateTimeline.demoSamples(records: session.records, interval: demoInterval)
        }
        return HeartRateTimeline(samples: samples, records: session.records, interval: interval)
    }

    var body: some View {
        let timeline = self.timeline
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isWaitingForOthers {
                    waitingBanner
                }
                // ヒーローは Figma の 402pt 座標で組むので、余白を打ち消して画面幅いっぱいに置く
                sharedPhotoSection
                    .padding(.horizontal, -16)
                    .padding(.top, -24)
                HeartRateTimelineView(
                    timeline: timeline,
                    missions: achievedMissions,
                    photo: photo(for:),
                    selectedMissionId: $selectedMissionId
                )
                VStack(spacing: 11) {
                    summaryText(timeline)
                    statCards(timeline)
                }
                HighlightSuggestionCard()
                buttons
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .safeAreaInset(edge: .top, spacing: 0) { headerBand }
        .onAppear {
            if selectedMissionId == nil {
                // 最初は最も心拍が上がっていたミッションを見せる
                let peak = timeline.peakBar?.index ?? 0
                selectedMissionId = timeline.marker(nearestTo: peak)?.missionId ?? achievedMissions.first?.id
            }
        }
        .task(id: session.membership?.code) {
            guard let code = session.membership?.code else { return }
            observer.start(code: code)
            await session.submitResultToRoomIfNeeded()
        }
    }

    private func photo(for mission: Mission) -> UIImage? {
        guard let record = session.records.first(where: { $0.missionId == mission.id }) else { return nil }
        return session.photo(for: record)
    }

    // MARK: - ヘッダ(緑帯)

    private var headerBand: some View {
        Text("\(session.plan.title) ふりかえり")
            .font(.handTitle)
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.6), radius: 0.5)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.appAccent)
    }

    // MARK: - 待機(他の人がまだ旅の途中)

    private var waitingBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.orange)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("他の人の終わりを待っています...")
                    .font(.handHeadline)
                    .foregroundStyle(Color.inkMain)
                Text("\(observer.results.count) / \(observer.partyCount) 人がゴール")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.badgeBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - 共通ミッションの写真

    /// 共通ミッション(isShared)の写真。無ければ達成時 bpm が最も高かった写真
    private var sharedRecord: MissionRecord? {
        let withPhoto = session.records.filter { session.photo(for: $0) != nil }
        let sharedIds = Set(session.plan.missions.filter { $0.isShared == true }.map(\.id))
        if let shared = withPhoto.first(where: { sharedIds.contains($0.missionId) }) { return shared }
        return withPhoto.max { ($0.bpmAtAchieve ?? 0) < ($1.bpmAtAchieve ?? 0) }
    }

    /// Figma の座標(幅 402pt 基準)で装飾を絶対配置するヒーロー。写真は -3.95° 傾けたポラロイド
    private var sharedPhotoSection: some View {
        let record = sharedRecord
        let comment = record?.aiComment ?? "\(session.records.count)つのミッションをやりとげた\nいい旅だったみたい"
        return GeometryReader { geometry in
            let scale = geometry.size.width / 402
            ZStack(alignment: .topLeading) {
                // ガーランド(左)と、左右反転した同じ素材(右)
                ForEach(Self.garland, id: \.name) { piece in
                    Image(piece.name)
                        .resizable()
                        .frame(width: piece.size.width, height: piece.size.height)
                        .position(x: piece.origin.x + piece.size.width / 2, y: piece.origin.y + piece.size.height / 2)
                    Image(piece.name)
                        .resizable()
                        .scaleEffect(x: -1)
                        .frame(width: piece.size.width, height: piece.size.height)
                        .position(x: 402 - piece.origin.x - piece.size.width / 2, y: piece.origin.y + piece.size.height / 2)
                }

                Group {
                    if let record, let image = session.photo(for: record) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray4)
                            .overlay {
                                Text("共通ミッションの写真")
                                    .font(.handHeadline)
                                    .foregroundStyle(Color.inkSub)
                            }
                    }
                }
                .frame(width: 272, height: 151)
                .clipped()
                .border(.white, width: 10)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
                .rotationEffect(.degrees(-3.95))
                .position(x: 201, y: 28.8 + 169.4 / 2)

                Image("DoodleStar")
                    .resizable()
                    .frame(width: 29.5, height: 30.3)
                    .position(x: 15.4 + 14.7, y: 214 + 15.1)

                Image("DoodleMonkey")
                    .resizable()
                    .scaleEffect(x: -1)
                    .frame(width: 71.9, height: 75)
                    .position(x: 301 + 36, y: 187 + 37.5)

                Text(comment)
                    .font(.handCaption.bold())
                    .foregroundStyle(Color.inkMain)
                    .multilineTextAlignment(.center)
                    .fixedSize()
                    .position(x: 201, y: 209 + 19)
            }
            .frame(width: 402, height: 250, alignment: .topLeading)
            .scaleEffect(scale, anchor: .topLeading)
        }
        .frame(height: 250)
    }

    /// ガーランドの左半分(Figma 座標。y は緑帯の下端を 0 とする)
    private static let garland: [(name: String, origin: CGPoint, size: CGSize)] = [
        ("Garland1", CGPoint(x: 112, y: -1.2), CGSize(width: 31.9, height: 32)),
        ("Garland2", CGPoint(x: 78.7, y: 20), CGSize(width: 36.5, height: 38.2)),
        ("Garland3", CGPoint(x: 44.6, y: 41.7), CGSize(width: 35.8, height: 36.5)),
        ("Garland4", CGPoint(x: 6.8, y: 58.6), CGSize(width: 37.5, height: 34.2)),
        ("Garland5", CGPoint(x: -4.9, y: 71), CGSize(width: 11.9, height: 23.1)),
    ]

    // MARK: - まとめの一文

    private func summaryText(_ timeline: HeartRateTimeline) -> some View {
        HStack(spacing: 8) {
            Image("DoodleHeart")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 20)
                .rotationEffect(.degrees(-18.8))
            Text("スマホを見なかった \(offlineText(long: true)) のあいだに\n心が動いた瞬間が \(timeline.spikeCount)回 ありました")
                .font(.handCaption)
                .foregroundStyle(Color.inkMain)
                .multilineTextAlignment(.center)
            Image("DoodleClover")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 26)
                .rotationEffect(.degrees(15.78))
        }
        .frame(maxWidth: .infinity)
    }

    private func offlineText(long: Bool) -> String {
        let minutes = Int(session.offlineDuration / 60)
        let h = minutes / 60, m = minutes % 60
        if long {
            return h > 0 ? "\(h)時間\(m)分" : "\(m)分"
        }
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - 3 つの指標

    private func statCards(_ timeline: HeartRateTimeline) -> some View {
        HStack(spacing: 8) {
            statCard(title: "目の前に夢中", label: "オフライン：", value: offlineText(long: false), frame: "StatFrame")
            statCard(title: "いろいろチャレンジ", label: "ミッション達成数：", value: "\(session.records.count)", frame: "StatFrame")
            statCard(title: "心が動いた", label: "最高心拍：",
                     value: timeline.maximumBpm.map { "\(Int($0.rounded()))bpm" } ?? "--", frame: "StatFrame2")
        }
    }

    private func statCard(title: String, label: String, value: String, frame: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.handCaption2.bold())
                .foregroundStyle(Color.inkMain)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkSub)
                Text(value)
                    .font(.handCaption2.bold())
                    .foregroundStyle(Color.inkMain)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .padding(.horizontal, 4)
        .background {
            Image(frame)
                .resizable()
        }
    }

    // MARK: - ボタン

    private var buttons: some View {
        VStack(spacing: 10) {
            ShareLink(item: "『\(session.plan.title)』を旅してきました! \(session.totalScore)pt(スマホは見ざる)#ミザル") {
                Text("結果をシェアする")
                    .font(.handHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background {
                        Image("BrushButton")
                            .resizable(resizingMode: .stretch)
                    }
            }
            .disabled(isWaitingForOthers)
            OutlineButton(label: "もう一回たびする", action: onRestart)
                .disabled(isWaitingForOthers)
        }
        .opacity(isWaitingForOthers ? 0.4 : 1)
        .padding(.top, 4)
    }
}

#Preview("ひとり旅(デモ)") {
    let plan = TravelPlan.bundledDemoPlan()
    let start = Date().addingTimeInterval(-4 * 3600 - 12 * 60)
    let records = plan.missions.enumerated().map { i, mission in
        MissionRecord(
            missionId: mission.id,
            achievedAt: start.addingTimeInterval(Double(i + 1) * 40 * 60),
            bpmAtAchieve: 90 + i * 10,
            points: mission.points,
            aiComment: i == 3 ? "4人でいろんなことをした\nいい旅だったみたい" : nil
        )
    }
    let interval = DateInterval(start: start, end: Date())
    let session = TripSession(snapshot: TripSessionSnapshot(
        plan: plan,
        phase: .finished,
        currentMissionId: nil,
        records: records,
        heartRateSamples: HeartRateTimeline.demoSamples(records: records, interval: interval),
        useMockJudge: true,
        tripStartedAt: start,
        tripEndedAt: Date(),
        foregroundSeconds: 0,
        becameActiveAt: nil,
        restrictionAdjustments: 0,
        shieldSelectionData: nil,
        savedAt: Date()
    ))
    ResultView(onRestart: {})
        .environment(session)
}
