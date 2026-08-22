//
//  PlanView.swift
//  SPAJAM2026App
//
//  02 プラン(ミッションログ)。手書き風フレームのリスト行で 5 ミッションを表示し、旅をはじめる。
//  デザイン: docs/mission-design.pen「02 プラン(ミッションログ)」/ docs/Figma 旅行開始前画面
//

import SwiftUI

struct PlanView: View {
    @Environment(TripSession.self) private var session
    var onStart: () -> Void

    @State private var observer = TripRoomObserver()
    @State private var isPublishing = false
    @State private var publishError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                Text("\(session.plan.missions.count)ミッション")
                    .font(.handCaption.bold())
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                ForEach(session.plan.missions) { mission in
                    MissionListRow(
                        mission: mission,
                        note: mission.isShared == true ? "共通ミッション" : nil
                    )
                }
                startButton
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .task(id: session.membership?.code) {
            if let membership = session.membership, membership.role == .host {
                observer.start(code: membership.code)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenHeader(session.plan.title, subtitle: session.plan.area)
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
            BrushButton(label: "旅をはじめる", loading: isPublishing, disabled: isPublishing, action: start)

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
}

/// 手書き風フレームのミッション行(02 プラン/04b ミッション一覧 共通)
struct MissionListRow: View {
    let mission: Mission
    var achieved = false
    var note: String?
    var photo: UIImage?

    var body: some View {
        HandFrameRow {
            HStack(spacing: 10) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MISSION \(mission.order):\(mission.title)")
                        .font(.handBody.bold())
                        .foregroundStyle(Color.inkMain)
                        .multilineTextAlignment(.leading)
                    if let note {
                        Text(note)
                            .font(.handCaption2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                CategoryBadge(label: mission.category.label, achieved: achieved)
            }
        }
    }
}
