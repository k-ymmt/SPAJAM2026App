//
//  TripMissionListView.swift
//  SPAJAM2026App
//
//  旅行中のメイン画面。全ミッションと達成状況を一覧し、タップで挑戦(カメラ)へ。
//  右上の設定から制限調整(調整すると OFFLINE SCORE が減る)。
//

import SwiftUI

struct TripMissionListView: View {
    @Environment(TripSession.self) private var session
    var onSelectMission: (Mission) -> Void
    var onOpenSettings: () -> Void
    var onEndTrip: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(session.plan.missions) { mission in
                        Button {
                            onSelectMission(mission)
                        } label: {
                            missionTile(mission)
                        }
                        .buttonStyle(.plain)
                        .disabled(session.isAchieved(mission))
                    }
                }
                Text("ミッションは好きな順番で OK。タップして挑戦しよう")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity)

                Button(action: onEndTrip) {
                    Text("旅をおわる")
                        .font(.handBody)
                        .foregroundStyle(Color.inkSub)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    @ViewBuilder
    private func missionTile(_ mission: Mission) -> some View {
        let achieved = session.isAchieved(mission)
        let record = session.records.first { $0.missionId == mission.id }

        if achieved, let record, let image = session.photo(for: record) {
            // 達成済み: 写真タイルに変わる(setlog 風)
            Color.clear
                .frame(height: 170)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(alignment: .topLeading) {
                    Text("\(mission.category.label)・達成")
                        .font(.handCaption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.teal)
                        .padding(10)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.white, .teal)
                        .padding(10)
                }
        } else {
            MissionTile(mission: mission, achieved: achieved)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.plan.title)
                    .font(.handTitle)
                HStack(spacing: 8) {
                    Text("達成 \(session.records.count)/\(session.plan.missions.count)")
                    if let bpm = session.heartRateReceiver.latest?.beatsPerMinute {
                        Label("\(Int(bpm))", systemImage: "heart.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.handCaption)
                .foregroundStyle(Color.inkSub)
            }
            Spacer()
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.handTitle)
                    .foregroundStyle(Color.inkSub)
                    .padding(10)
                    .background(.white, in: Circle())
            }
        }
    }
}
