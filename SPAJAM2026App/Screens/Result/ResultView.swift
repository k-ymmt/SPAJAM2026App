//
//  ResultView.swift
//  SPAJAM2026App
//
//  05 リザルト(みんなの旅の記録)。個人スコアと共有体験を 1 画面に統合:
//  スコア強調ファーストビュー → 順位なしのメンバー発表 → 心拍のうごき →
//  ミッションたっせい → 心拍ハイライト×写真(たのしかった瞬間)→ シェア。
//  複数人の旅(membership あり)は rooms/{code}/results をリアルタイム購読して本物のメンバーを表示し、
//  全員が終わるまで待機表示にする。ひとり旅はデモ用の事前読み込みデータ。
//  デザイン: docs/mission-design.pen「05 リザルト(みんなの旅の記録)」
//

import SwiftUI

/// 結果発表に並ぶメンバー 1 人分の結果
struct MemberResult: Identifiable {
    var id: String { name }
    var name: String
    var color: Color
    var isMe = false
    var total: Int
    var achievedMissionIds: Set<String>
    /// 時間帯ごとの心拍変動量(グラフ用・正規化済み 0...1)
    var bpmBars: [Double]

    /// 他のメンバーに順番に割り当てる色
    static let memberColors: [Color] = [
        .appAccentSoft,
        Color(red: 0.769, green: 0.643, blue: 0.420),
        Color(red: 0.45, green: 0.62, blue: 0.55),
        Color(red: 0.55, green: 0.50, blue: 0.72),
    ]

    /// 実同期: 自分(ローカル)+ルームに届いた他メンバーの結果
    static func party(for session: TripSession, results: [TripMemberResult], myUid: String?) -> [MemberResult] {
        let me = MemberResult(
            name: "あなた",
            color: .appAccent,
            isMe: true,
            total: session.totalScore,
            achievedMissionIds: Set(session.records.map(\.missionId)),
            bpmBars: session.myBars
        )
        let others = results
            .filter { $0.id != myUid }
            .enumerated()
            .map { index, result in
                MemberResult(
                    name: result.name,
                    color: memberColors[index % memberColors.count],
                    total: result.total,
                    achievedMissionIds: Set(result.achievedMissionIds),
                    bpmBars: result.bpmBars.count == 6 ? result.bpmBars : [0.3, 0.3, 0.3, 0.3, 0.3, 0.3]
                )
            }
        return [me] + others
    }

    /// デモ用: 自分+事前読み込みの 2 人(実対戦はせず結果発表で見せる方針)
    static func demoParty(for session: TripSession) -> [MemberResult] {
        let missions = session.plan.missions
        let me = MemberResult(
            name: "あなた",
            color: .appAccent,
            isMe: true,
            total: session.totalScore,
            achievedMissionIds: Set(session.records.map(\.missionId)),
            bpmBars: session.myBars
        )

        var yamaAchieved = Set(missions.map(\.id))
        if let drop = missions.dropFirst(2).first { yamaAchieved.remove(drop.id) }
        let yamaPoints = missions.filter { yamaAchieved.contains($0.id) }.reduce(0) { $0 + $1.points }
        let yama = MemberResult(
            name: "やま",
            color: .appAccentSoft,
            total: yamaPoints + max(0, session.heartScore * 7 / 10 + 3) + max(0, session.offlineScore * 8 / 10),
            achievedMissionIds: yamaAchieved,
            bpmBars: [0.3, 0.42, 0.5, 0.44, 0.36, 0.4]
        )

        var hiroAchieved = Set(missions.map(\.id))
        if let drop = missions.dropFirst(4).first { hiroAchieved.remove(drop.id) }
        let hiroPoints = missions.filter { hiroAchieved.contains($0.id) }.reduce(0) { $0 + $1.points }
        let hiro = MemberResult(
            name: "ひろ",
            color: Color(red: 0.769, green: 0.643, blue: 0.420),
            total: hiroPoints + max(0, session.heartScore * 9 / 10) + max(0, session.offlineScore * 7 / 10),
            achievedMissionIds: hiroAchieved,
            bpmBars: [0.5, 0.35, 0.65, 0.5, 0.7, 0.45]
        )
        return [me, yama, hiro]
    }
}

struct ResultView: View {
    @Environment(TripSession.self) private var session
    var onRestart: () -> Void

    @State private var observer = TripRoomObserver()

    private var isShared: Bool { session.membership != nil }

    /// 複数人の旅で、まだ終わっていない人がいる
    private var isWaitingForOthers: Bool { isShared && !observer.isAllFinished }

    private var party: [MemberResult] {
        if isShared {
            MemberResult.party(for: session, results: observer.results, myUid: AuthService.shared.uid)
        } else {
            MemberResult.demoParty(for: session)
        }
    }

    var body: some View {
        let party = self.party
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                scoreCard
                if isWaitingForOthers {
                    waitingBanner
                } else {
                    sharedBanner
                }
                memberCards(party)
                heartSection(party)
                missionSection(party)
                highlightSection
                buttons
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .task(id: session.membership?.code) {
            guard let code = session.membership?.code else { return }
            observer.start(code: code)
            await session.submitResultToRoomIfNeeded()
        }
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

    private var header: some View {
        ScreenHeader("旅のリザルト", subtitle: "\(session.plan.title) ・ \(session.plan.missions.count)ミッション")
    }

    // MARK: - スコア(ファーストビュー)

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text("\(session.totalScore) pt")
                .font(.handNumber(48))
                .foregroundStyle(Color.inkMain)
            HStack(spacing: 12) {
                scoreItem(label: "QUEST", sub: "ミッション達成", value: session.questScore)
                scoreItem(label: "HEART", sub: "心の動き", value: session.heartScore)
                scoreItem(label: "OFFLINE", sub: "スマホみない", value: session.offlineScore)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 9, y: 6)
    }

    private func scoreItem(label: String, sub: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)pt").font(.handHeadline).foregroundStyle(Color.appAccent)
            Text(label).font(.handCaption2.bold()).foregroundStyle(Color.badgeText)
            Text(sub).font(.handCaption2).foregroundStyle(Color.inkSub)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 共有体験(順位なし)

    private var sharedBanner: some View {
        HStack(spacing: 12) {
            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .padding(5)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("みんな、旅に集中できました!")
                    .font(.handHeadline)
                    .foregroundStyle(Color.inkMain)
                Text("順位はなし。たのしかった瞬間をシェアしよう")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.badgeBackground, in: RoundedRectangle(cornerRadius: 20))
    }

    private func memberCards(_ party: [MemberResult]) -> some View {
        HStack(spacing: 10) {
            ForEach(party) { member in
                VStack(spacing: 4) {
                    Circle()
                        .fill(member.color)
                        .frame(width: 40, height: 40)
                    Text(member.name)
                        .font(.handCaption)
                        .foregroundStyle(Color.inkMain)
                    Text("\(member.total)pt")
                        .font(.handHeadline)
                        .foregroundStyle(Color.appAccent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - 心拍のうごき

    private func heartSection(_ party: [MemberResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("心拍のうごき")
                    .font(.handHeadline)
                    .foregroundStyle(Color.inkMain)
                Spacer()
                ForEach(party) { member in
                    HStack(spacing: 4) {
                        Circle().fill(member.color).frame(width: 8, height: 8)
                        Text(member.name).font(.handCaption2).foregroundStyle(Color.inkSub)
                    }
                }
            }
            // 時間帯ごとのグループ棒グラフ(上下が大きい = 楽しめている)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(party) { member in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(member.isMe ? member.color : member.color.opacity(0.6))
                                .frame(height: max(8, 62 * (member.bpmBars[safe: i] ?? 0.3)))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - ミッションたっせい

    private func missionSection(_ party: [MemberResult]) -> some View {
        let done = party.reduce(0) { $0 + $1.achievedMissionIds.count }
        let total = session.plan.missions.count * party.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ミッションたっせい")
                    .font(.handHeadline)
                    .foregroundStyle(Color.inkMain)
                Spacer()
                Text("みんなで \(done)/\(total)")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            ForEach(session.plan.missions) { mission in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(.handBody)
                            .foregroundStyle(Color.inkMain)
                            .lineLimit(1)
                        Text(mission.category.label)
                            .font(.handCaption2)
                            .foregroundStyle(Color.inkSub)
                    }
                    Spacer()
                    ForEach(party) { member in
                        statusCircle(achieved: member.achievedMissionIds.contains(mission.id), color: member.color)
                    }
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func statusCircle(achieved: Bool, color: Color) -> some View {
        Image(systemName: achieved ? "checkmark" : "xmark")
            .font(.handCaption)
            .foregroundStyle(achieved ? .white : Color(.systemGray))
            .frame(width: 26, height: 26)
            .background(achieved ? color : Color(.systemGray5), in: Circle())
    }

    // MARK: - たのしかった瞬間(心拍ハイライト × 写真)

    /// 達成時 bpm が高かった順に上位 2 件(写真があるものだけ。bpm なしは後ろに回す)
    private var highlights: [MissionRecord] {
        session.records
            .filter { session.photo(for: $0) != nil }
            .sorted { ($0.bpmAtAchieve ?? 0) > ($1.bpmAtAchieve ?? 0) }
            .prefix(2)
            .map { $0 }
    }

    @ViewBuilder
    private var highlightSection: some View {
        let highlights = self.highlights
        if !highlights.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("たのしかった瞬間")
                        .font(.handHeadline)
                        .foregroundStyle(Color.inkMain)
                    Spacer()
                    Text("心拍ハイライト × 写真")
                        .font(.handCaption2)
                        .foregroundStyle(Color.inkSub)
                }
                HStack(spacing: 10) {
                    ForEach(highlights) { record in
                        highlightCard(record)
                    }
                }
            }
        }
    }

    private func highlightCard(_ record: MissionRecord) -> some View {
        let mission = session.plan.missions.first { $0.id == record.missionId }
        return VStack(alignment: .leading, spacing: 0) {
            Group {
                if let image = session.photo(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(.systemGray5)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 1) {
                Text("\(record.achievedAt.formatted(date: .omitted, time: .shortened))\(record.bpmAtAchieve.map { " ・ \($0)bpm ↑" } ?? "")")
                    .font(.handCaption2.bold())
                    .foregroundStyle(Color.inkMain)
                Text(mission?.title ?? "")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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

extension TripSession {
    /// 自分の心拍サンプルを 6 区間の変動量に集計(サンプルが無ければダミー波形)
    var myBars: [Double] {
        let samples = heartRateSamples.map(\.bpm)
        guard samples.count >= 6 else { return [0.35, 0.6, 0.45, 0.8, 0.5, 0.9] }
        let chunk = max(1, samples.count / 6)
        let mean = samples.reduce(0, +) / Double(samples.count)
        return (0..<6).map { i in
            let slice = samples.dropFirst(i * chunk).prefix(chunk)
            guard !slice.isEmpty else { return 0.3 }
            let dev = slice.reduce(0) { $0 + abs($1 - mean) } / Double(slice.count)
            return min(1.0, 0.25 + dev / 30)
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
