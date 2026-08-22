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

    @State private var observer = TripRoomObserver()
    @State private var isPublishing = false
    @State private var publishError: String?

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
        .task(id: session.membership?.code) {
            if let membership = session.membership, membership.role == .host {
                observer.start(code: membership.code)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenHeader(session.plan.title, subtitle: "\(session.plan.missions.count)ミッション・\(session.plan.area)")
            if let membership = session.membership {
                companions(membership)
            }
        }
    }

    /// いっしょに行く人(親: 参加者名、子: 参加中の名前)
    private func companions(_ membership: RoomMembership) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(.orange)
            switch membership.role {
            case .host:
                let names = observer.members.map(\.name)
                Text(names.isEmpty ? "参加者を待っています(コード \(membership.code))" : "いっしょに行く: " + names.joined(separator: "、"))
            case .guest:
                Text("\(membership.name ?? "") として参加中(コード \(membership.code))")
            }
        }
        .font(.handCaption)
        .foregroundStyle(Color.inkSub)
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            Button(action: start) {
                HStack(spacing: 8) {
                    if isPublishing { ProgressView().tint(.white) }
                    Text("旅をはじめる")
                }
                .font(.handHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isPublishing)

            if let publishError {
                Text(publishError)
                    .font(.handCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }

            Text("はじめるとスマホはおやすみモードになります")
                .font(.handCaption2)
                .foregroundStyle(Color.inkSub)
                .frame(maxWidth: .infinity)

            judgeToggle
        }
        .padding(.top, 8)
    }

    /// 親ならプランをルームに公開してから(待機中の子も開始)次へ進む
    private func start() {
        isPublishing = true
        publishError = nil
        Task {
            do {
                try await session.publishPlanToRoomIfHost()
                onStart()
            } catch {
                NSLog("[Room] publish failed: \(error)")
                publishError = "プランを共有できませんでした。通信環境を確認してもう一度お試しください"
            }
            isPublishing = false
        }
    }

    /// デモ用: AI 判定の Mock/Live 切り替え(電波なし対策)
    private var judgeToggle: some View {
        @Bindable var session = session
        return Toggle(isOn: $session.useMockJudge) {
            Text("Mock 判定(電波なしデモ用)")
                .font(.handCaption)
                .foregroundStyle(Color.inkSub)
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
                .foregroundStyle(Color.inkSub)
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
