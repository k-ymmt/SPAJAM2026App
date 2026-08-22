//
//  ResultView.swift
//  SPAJAM2026App
//
//  05 リザルト。ミッションログ(写真×時刻×bpm)とスコア 3 要素を表示する。
//  デザイン: docs/mission-design.pen「05 リザルト」
//

import SwiftUI

struct ResultView: View {
    @Environment(TripSession.self) private var session
    var onRestart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                scoreCard
                missionLog
                restartButton
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("旅のリザルト")
                .font(.title2.bold())
            Text(session.plan.title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text("\(session.totalPoints + session.focusScore) pt")
                .font(.system(size: 44, weight: .bold))
            HStack(spacing: 20) {
                scoreItem(label: "ミッション", value: "\(session.totalPoints)pt")
                scoreItem(label: "心拍のゆらぎ", value: "\(session.focusScore)pt")
                scoreItem(label: "みない時間", value: "—")
            }
            Text("スクリーンタイム連携は実装中(P1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 9, y: 6)
    }

    private func scoreItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var missionLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ミッション ログ")
                .font(.headline)
            ForEach(session.records) { record in
                logRow(record)
            }
        }
    }

    private func logRow(_ record: MissionRecord) -> some View {
        let mission = session.plan.missions.first { $0.id == record.missionId }
        return HStack(spacing: 12) {
            Text(record.achievedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Group {
                if let image = session.photo(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: mission?.category.symbolName ?? "checkmark")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(mission?.title ?? record.missionId)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                Text("\(mission?.category.label ?? "")・達成 +\(record.points)pt")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let bpm = record.bpmAtAchieve {
                Text("\(bpm)bpm")
                    .font(.caption2.bold())
                    .foregroundStyle(.orange)
            }
        }
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Text("もう一回たびする")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
}
