//
//  TripMissionListView.swift
//  SPAJAM2026App
//
//  旅行中のメイン画面。プラン画面と同じヘッダ+MISSION タブ付きリストで達成状況を一覧し、
//  タップで挑戦(カメラ)へ。達成行は CLEAR バッジ+ポラロイド写真に変わる。
//  ヘッダ右の設定から制限調整(調整すると OFFLINE SCORE が減る)。
//  デザイン: docs/Figma 旅行開始前画面(2 日目更新版)と共通
//

import SwiftUI

struct TripMissionListView: View {
    @Environment(TripSession.self) private var session
    var onSelectMission: (Mission) -> Void
    var onOpenSettings: () -> Void
    var onEndTrip: () -> Void

    var body: some View {
        MissionListScreen(
            plan: session.plan,
            trailing: AnyView(HeaderIconButton(systemName: "gearshape.fill", action: onOpenSettings)),
            ctaLabel: "ただいま",
            onCTA: onEndTrip
        ) { mission in
            AnyView(missionRow(mission))
        }
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
                photo: record.flatMap { session.photo(for: $0) }
            )
        }
        .buttonStyle(.plain)
    }
}
