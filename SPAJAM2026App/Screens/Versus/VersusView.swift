//
//  VersusView.swift
//  SPAJAM2026App
//
//  07 ふたりの旅くらべ。心拍の推移(上下が大きい方が楽しめてる)とミッション達成を比較。
//  P1 は Mock 対戦データ。同期(Firebase/招待コード)につなぐときは OpponentData の生成を差し替える。
//  デザイン: docs/mission-design.pen「07 ふたりの旅くらべ(対戦リザルト)」
//

import SwiftUI

struct OpponentData {
    var name: String
    var achievedMissionIds: Set<String>
    var points: Int
    var focusScore: Int
    var notLookingScore: Int
    /// 時間帯ごとの心拍変動量(グラフ用・正規化済み 0...1)
    var bpmBars: [Double]

    var total: Int { points + focusScore + notLookingScore }

    /// Mock: 自分より少し控えめな対戦相手を生成する
    static func mock(for session: TripSession) -> OpponentData {
        let missions = session.plan.missions
        // 最後の 2 ミッションのうち 1 つを落とした想定
        var achieved = Set(missions.map(\.id))
        if let drop = missions.dropFirst(2).randomElement() { achieved.remove(drop.id) }
        let points = missions.filter { achieved.contains($0.id) }.reduce(0) { $0 + $1.points }
        return OpponentData(
            name: "あいて",
            achievedMissionIds: achieved,
            points: points,
            focusScore: max(0, session.heartScore * 7 / 10 + 3),
            notLookingScore: max(0, session.offlineScore * 8 / 10),
            bpmBars: [0.3, 0.4, 0.5, 0.45, 0.35, 0.4]
        )
    }
}

struct VersusView: View {
    @Environment(TripSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    var onRestart: () -> Void

    private var opponent: OpponentData { OpponentData.mock(for: session) }

    var body: some View {
        let opponent = self.opponent
        let myTotal = session.totalScore
        let opTotal = opponent.total
        let iWin = myTotal >= opTotal

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                winnerCard(iWin: iWin, myTotal: myTotal, opTotal: opTotal)
                heartSection(opponent: opponent)
                missionSection(opponent: opponent)
                buttons
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ふたりの旅くらべ")
                .font(.title2.bold())
            Text(session.plan.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func winnerCard(iWin: Bool, myTotal: Int, opTotal: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(.orange, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(iWin ? "たのしみ勝ちは あなた!" : "たのしみ勝ちは あいて!")
                    .font(.subheadline.bold())
                Text("あなた \(myTotal)pt ・ あいて \(opTotal)pt(QUEST+HEART+OFFLINE)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private func heartSection(opponent: OpponentData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("心拍のうごき")
                    .font(.headline)
                Spacer()
                legend(color: .orange, label: "あなた")
                legend(color: .teal, label: "あいて")
            }
            // 時間帯ごとのペア棒グラフ(上下が大きい = 楽しめている)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(myBars.enumerated()), id: \.offset) { i, mine in
                    HStack(alignment: .bottom, spacing: 3) {
                        bar(height: mine, color: .orange)
                        bar(height: opponent.bpmBars[safe: i] ?? 0.3, color: .teal.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
            .padding(14)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    /// 自分の心拍サンプルを 6 区間に集計(サンプルが無ければダミー波形)
    private var myBars: [Double] {
        let samples = session.heartRateSamples.map(\.bpm)
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

    private func bar(height: Double, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(height: max(8, 62 * height))
            .frame(maxWidth: .infinity)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func missionSection(opponent: OpponentData) -> some View {
        let myAchieved = Set(session.records.map(\.missionId))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ミッションたいせん")
                    .font(.headline)
                Spacer()
                Text("あなた \(myAchieved.count)/\(session.plan.missions.count)・あいて \(opponent.achievedMissionIds.count)/\(session.plan.missions.count)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(session.plan.missions) { mission in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        Text("\(mission.category.label)・\(mission.slot.label)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusCircle(achieved: myAchieved.contains(mission.id), color: .orange)
                    statusCircle(achieved: opponent.achievedMissionIds.contains(mission.id), color: .teal)
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func statusCircle(achieved: Bool, color: Color) -> some View {
        Image(systemName: achieved ? "checkmark" : "xmark")
            .font(.caption.bold())
            .foregroundStyle(achieved ? .white : Color(.systemGray))
            .frame(width: 26, height: 26)
            .background(achieved ? color : Color(.systemGray5), in: Circle())
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            ShareLink(item: "『\(session.plan.title)』でたのしみ勝ち! \(session.totalPoints + session.focusScore)pt 獲得 #オフラインクエスト") {
                Text("結果をシェアする")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.orange, in: Capsule())
                    .foregroundStyle(.white)
            }
            Button {
                dismiss()
                onRestart()
            } label: {
                Text("もう一回たびする")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Color(.systemGray4)))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
