//
//  PlanView.swift
//  SPAJAM2026App
//
//  02 プラン(旅行開始直前)。タイトル+日付+メンバー+ミザルの吹き出しの下に、
//  MISSION タブ付きの手書きフレームで 5 ミッションを表示し、旅をはじめる。
//  デザイン: docs/Figma 旅行開始前画面(2 日目更新版)
//

import SwiftUI

struct PlanView: View {
    @Environment(TripSession.self) private var session
    var onStart: () -> Void

    @State private var observer = TripRoomObserver()
    @State private var isPublishing = false
    @State private var publishError: String?

    var body: some View {
        MissionListScreen(
            plan: session.plan,
            ctaLabel: "いってきます",
            ctaLoading: isPublishing,
            errorText: publishError,
            onCTA: start
        ) { mission in
            AnyView(MissionListRow(mission: mission))
        }
        .task(id: session.membership?.code) {
            if let membership = session.membership, membership.role == .host {
                observer.start(code: membership.code)
            }
        }
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

/// プラン(いってきます)と旅行中(ただいま)で共通のミッション一覧画面。
/// ヘッダ・行・フッターの設計と配置を完全に揃える
struct MissionListScreen: View {
    let plan: TravelPlan
    var trailing: AnyView?
    let ctaLabel: String
    var ctaLoading = false
    var errorText: String?
    let onCTA: () -> Void
    let row: (Mission) -> AnyView

    var body: some View {
        // スクロールなしで 1 画面に収める
        VStack(alignment: .leading, spacing: 10) {
            PlanHeaderView(plan: plan, trailing: trailing)
            ForEach(plan.missions) { mission in
                row(mission)
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Divider()
                    .overlay(Color.cardStroke)
                    .padding(.top, 4)
                BrushButton(label: ctaLabel, loading: ctaLoading, disabled: ctaLoading, action: onCTA)
                if let errorText {
                    Text(errorText)
                        .font(.handCaption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.appBackground)
    }
}

/// プラン/旅行中一覧の共通ヘッダ: タイトル + 日付・人数 + メンバー + ミザルの吹き出し
struct PlanHeaderView: View {
    let plan: TravelPlan
    /// ヘッダ右端に置く小さいボタン(旅行中の制限調整など)
    var trailing: AnyView?

    private static let avatarColors: [Color] = [
        Color(red: 0.847, green: 0.694, blue: 0.549), // D8B18C
        Color(red: 0.616, green: 0.722, blue: 0.627), // 9DB8A0
        Color(red: 0.478, green: 0.620, blue: 0.576), // 7A9E93
        Color(red: 0.769, green: 0.643, blue: 0.420), // C4A46B
        Color(red: 0.561, green: 0.737, blue: 0.690), // appAccentSoft
    ]

    private var partyLabel: String {
        switch plan.partySize ?? 1 {
        case 1: "ひとり旅"
        case 2: "ふたり旅"
        case let n: "\(n)人旅"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.title)
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.65), radius: 0.5)
                Spacer()
                if let trailing {
                    trailing
                }
            }

            HStack(spacing: 14) {
                Text(Date.now.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                Text(partyLabel)
            }
            .font(.handCaption)
            .foregroundStyle(Color.inkSub)

            HStack(spacing: 8) {
                Text("メンバー")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                ForEach(0..<min(plan.partySize ?? 1, 5), id: \.self) { i in
                    Circle()
                        .fill(Self.avatarColors[i % Self.avatarColors.count])
                        .frame(width: 34, height: 34)
                }
            }
            .padding(.bottom, 6)
        }
    }
}

/// MISSION タブ付きの手書きフレーム行(02 プラン/04b ミッション一覧 共通)。
/// 達成すると CLEAR バッジとポラロイド風の写真が付く。
struct MissionListRow: View {
    let mission: Mission
    var achieved = false
    var photo: UIImage?

    private var frameNumber: Int { min(max(mission.order, 1), 5) }

    var body: some View {
        // デザイン素材(枠+MISSION タブ+ミザル入り)を行の背景として使う。
        // 達成後はクリア版素材に切り替え、写真プレースホルダ位置に撮影写真をはめる
        Image(achieved ? "MissionClearFrame\(frameNumber)" : "MissionFrame\(frameNumber)")
            .resizable()
            .scaledToFit()
            .overlay(alignment: .leading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mission.title)
                        .font(.handBody.bold())
                        .foregroundStyle(Color.inkMain)
                        .multilineTextAlignment(.leading)
                    if mission.isShared == true {
                        Text("-共通ミッション")
                            .font(.handCaption2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                .padding(.leading, 26)
                .padding(.trailing, 116)
                // タブの分だけ下の枠内で縦中央に
                .offset(y: 7)
            }
            .overlay(alignment: .trailing) {
                // 素材のプレースホルダ(約 104x69pt / 右 6pt / -3.6°)に写真をはめる
                if achieved, let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 104, height: 69)
                        .clipped()
                        .overlay { ClearBadge() }
                        .rotationEffect(.degrees(-3.6))
                        .padding(.trailing, 6)
                        .offset(y: 1.5)
                }
            }
    }
}

/// 達成バッジ(枠線の CLEAR)
struct ClearBadge: View {
    var body: some View {
        Text("CLEAR")
            .font(.system(size: 14, weight: .bold))
            .kerning(1)
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.appAccent, lineWidth: 1.8))
    }
}

