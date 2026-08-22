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
    @State private var showVersus = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                scoreCard
                missionLog
                versusButton
                restartButton
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
        .sheet(isPresented: $showVersus) {
            VersusView(onRestart: onRestart)
                .environment(session)
        }
    }

    private var versusButton: some View {
        Button {
            showVersus = true
        } label: {
            Label("ふたりの旅くらべを見る", systemImage: "person.2.fill")
                .font(.handHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.teal)
    }

    private var header: some View {
        ScreenHeader("旅のリザルト", subtitle: session.plan.title)
    }

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text("\(session.totalScore) pt")
                .font(.handNumber(48))
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
            Text("\(value)pt").font(.handHeadline)
            Text(label).font(.handCaption2).foregroundStyle(.orange)
            Text(sub).font(.handCaption2).foregroundStyle(Color.inkSub)
        }
        .frame(maxWidth: .infinity)
    }

    private var missionLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ミッション ログ")
                .font(.handHeadline)
            ForEach(session.records) { record in
                logRow(record)
            }
        }
    }

    private func logRow(_ record: MissionRecord) -> some View {
        let mission = session.plan.missions.first { $0.id == record.missionId }
        return HStack(spacing: 12) {
            Text(record.achievedAt.formatted(date: .omitted, time: .shortened))
                .font(.handCaption2)
                .foregroundStyle(Color.inkSub)
            Group {
                if let image = session.photo(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: mission?.category.symbolName ?? "checkmark")
                        .foregroundStyle(Color.inkSub)
                }
            }
            .frame(width: 44, height: 44)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(mission?.title ?? record.missionId)
                    .font(.handBody)
                    .lineLimit(1)
                Text("\(mission?.category.label ?? "")・達成 +\(record.points)pt")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            Spacer()
            if let bpm = record.bpmAtAchieve {
                Text("\(bpm)bpm")
                    .font(.handCaption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Text("もう一回たびする")
                .font(.handHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }
}
