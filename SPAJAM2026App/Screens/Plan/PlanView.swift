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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                Text("\(session.plan.missions.count)ミッション")
                    .font(.handCaption.bold())
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                ForEach(session.plan.missions) { mission in
                    MissionListRow(mission: mission)
                }
                startButton
            }
            .padding(24)
        }
        .background(Color.appBackground)
    }

    private var header: some View {
        ScreenHeader(session.plan.title, subtitle: session.plan.area)
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            BrushButton(label: "旅をはじめる", action: onStart)

            Text("はじめるとスマホはおやすみモードになります")
                .font(.handCaption2)
                .foregroundStyle(Color.inkSub)
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
                .foregroundStyle(Color.inkSub)
        }
        .tint(.appAccent)
        .padding(.horizontal, 4)
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
