//
//  TripMissionListView.swift
//  SPAJAM2026App
//
//  旅行中に撮影画面から開くミッション一覧。全ミッションと達成状況を確認できる。
//  右上の設定ボタンから制限調整へ(調整すると OFFLINE SCORE が減る)。
//

import SwiftUI

struct TripMissionListView: View {
    @Environment(TripSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    /// 設定(制限調整)を開く。一覧を閉じてから呼ばれる
    var onOpenSettings: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(session.plan.missions) { mission in
                        MissionTile(mission: mission, achieved: session.isAchieved(mission))
                            .overlay {
                                if mission.id == session.currentMission?.id {
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(Color.orange, lineWidth: 3)
                                }
                            }
                    }
                }
                Text("オレンジ枠がいまのミッション。達成すると次に進みます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.plan.title)
                    .font(.title3.bold())
                Text("達成 \(session.records.count)/\(session.plan.missions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.white, in: Circle())
            }
        }
    }
}
