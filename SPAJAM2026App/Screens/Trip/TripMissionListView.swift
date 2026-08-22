//
//  TripMissionListView.swift
//  SPAJAM2026App
//
//  旅行中のメイン画面。プラン画面と同じ手書き風リストで全ミッションと達成状況を一覧し、
//  タップで挑戦(カメラ)へ。達成行は写真サムネ+済バッジに変わる。
//  右上の設定から制限調整(調整すると OFFLINE SCORE が減る)。
//

import SwiftUI

struct TripMissionListView: View {
    @Environment(TripSession.self) private var session
    var onSelectMission: (Mission) -> Void
    var onOpenSettings: () -> Void
    var onEndTrip: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                ForEach(session.plan.missions) { mission in
                    missionRow(mission)
                }
                Text("ミッションは好きな順番で OK。タップして挑戦しよう")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                OutlineButton(label: "旅をおわる", tint: .appAccent, action: onEndTrip)
            }
            .padding(24)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func missionRow(_ mission: Mission) -> some View {
        let achieved = session.isAchieved(mission)
        let record = session.records.first { $0.missionId == mission.id }

        Button {
            onSelectMission(mission)
        } label: {
            MissionListRow(
                mission: mission,
                achieved: achieved,
                note: achieved ? "達成! タップで写真をみる" : (mission.isShared == true ? "共通ミッション" : nil),
                photo: record.flatMap { session.photo(for: $0) }
            )
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        ScreenHeader(session.plan.title, subtitle: subtitleText) {
            HeaderIconButton(systemName: "gearshape.fill", action: onOpenSettings)
        }
    }

    private var subtitleText: String {
        var text = "達成 \(session.records.count)/\(session.plan.missions.count)"
        if let bpm = session.heartRateReceiver.latest?.beatsPerMinute {
            text += " ・ ♥ \(Int(bpm))bpm"
        }
        return text
    }
}
