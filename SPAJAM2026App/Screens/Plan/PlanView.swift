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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PlanHeaderView(plan: session.plan)
                ForEach(session.plan.missions) { mission in
                    MissionListRow(mission: mission)
                }
                footer
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

    private var footer: some View {
        VStack(spacing: 10) {
            Divider()
                .overlay(Color.cardStroke)
                .padding(.top, 4)
            BrushButton(label: "旅をはじめる", loading: isPublishing, disabled: isPublishing, action: start)
            if let publishError {
                Text(publishError)
                    .font(.handCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
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

            // ミザルの吹き出し
            HStack(spacing: 4) {
                Text("今回のミッションは\nこれだよっ")
                    .font(.handTitle)
                    .foregroundStyle(Color.inkMain)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Image("MizaruCharacter")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
            }
            .padding(.top, 6)
        }
    }
}

/// MISSION タブ付きの手書きフレーム行(02 プラン/04b ミッション一覧 共通)。
/// 達成すると CLEAR バッジとポラロイド風の写真が付く。
struct MissionListRow: View {
    let mission: Mission
    var achieved = false
    var photo: UIImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            HandFrameRow {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                // 写真と重ならないように右を空ける
                .padding(.trailing, achieved ? 140 : 0)
            }
            .padding(.top, 11)

            // 枠の上辺にまたがる MISSION タブ
            Text("MISSION \(mission.order)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.inkMain)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(Color.appBackground)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appAccent, lineWidth: 1.8))
                .padding(.leading, 14)
        }
        .overlay(alignment: .trailing) {
            if achieved {
                PolaroidThumb(image: photo)
                    .offset(x: 4)
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

/// ポラロイド風の写真サムネイル。中央に CLEAR バッジを重ねる
struct PolaroidThumb: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(.systemGray4)
            }
        }
        .frame(width: 148, height: 96)
        .clipped()
        .overlay { ClearBadge() }
        .padding(6)
        .background(.white)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .rotationEffect(.degrees(3))
    }
}
