//
//  PlanView.swift
//  SPAJAM2026App
//
//  02 プラン(ミッションログ)。setlog 風タイルで固定 3 + 変動 2 を表示し、旅をはじめる。
//  デザイン: docs/mission-design.pen「02 プラン(ミッションログ)」
//

import SwiftUI

struct PlanView: View {
    @Environment(TripSession.self) private var session
    var onStart: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(session.plan.missions) { mission in
                        MissionTile(mission: mission, achieved: session.isAchieved(mission))
                    }
                }
                startButton
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.plan.title)
                .font(.handLargeTitle)
            Text("\(session.plan.missions.count)ミッション・\(session.plan.area)")
                .font(.handCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            Button(action: onStart) {
                Text("旅をはじめる")
                    .font(.handHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

            Text("はじめるとスマホはおやすみモードになります")
                .font(.handCaption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            judgeToggle
        }
        .padding(.top, 8)
    }

    /// デモ用: AI 判定の Mock/Live 切り替え(電波なし対策)
    private var judgeToggle: some View {
        @Bindable var session = session
        return Toggle(isOn: $session.useMockJudge) {
            Text("Mock 判定(電波なしデモ用)")
                .font(.handCaption)
                .foregroundStyle(.secondary)
        }
        .tint(.orange)
        .padding(.horizontal, 4)
    }
}

struct MissionTile: View {
    let mission: Mission
    let achieved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(mission.category.label)
                    .font(.handCaption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeBackground, in: Capsule())
                    .foregroundStyle(badgeForeground)
                Spacer()
                if achieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                }
            }
            Image(systemName: mission.category.symbolName)
                .font(.handTitle)
            Text(mission.title)
                .font(.handBody)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Text(achieved ? "達成" : "未達成")
                .font(.handCaption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(height: 170)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 9, y: 6)
    }

    private var badgeBackground: Color {
        mission.slot == .fixed ? Color.teal.opacity(0.15) : Color.orange.opacity(0.15)
    }

    private var badgeForeground: Color {
        mission.slot == .fixed ? .teal : .orange
    }
}
