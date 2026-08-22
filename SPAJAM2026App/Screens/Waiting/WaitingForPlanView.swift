//
//  WaitingForPlanView.swift
//  SPAJAM2026App
//
//  招待コードで参加した子の待機画面。親が「旅をはじめる」を押してプランが公開されるまで待つ。
//

import SwiftUI

struct WaitingForPlanView: View {
    let membership: RoomMembership
    /// 親がプランを公開したとき
    var onPlanReady: (TravelPlan) -> Void
    /// 退出(待機をやめて最初に戻る)
    var onLeave: () -> Void

    @State private var observer = TripRoomObserver()
    @State private var isLeaving = false

    var body: some View {
        VStack(spacing: 20) {
            ScreenHeader("いっしょに旅をする", subtitle: "招待コード \(membership.code)")

            Spacer()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.appAccent)
                Text("一緒に行く人がプランを作成するのを待ってます...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkMain)
                    .multilineTextAlignment(.center)
                if let name = membership.name {
                    Text("\(name) として参加中")
                        .font(.handCaption)
                        .foregroundStyle(Color.inkSub)
                }
                if observer.code != nil, observer.room == nil {
                    Text("ルームが見つかりません。親がルームを閉じた可能性があります")
                        .font(.handCaption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 9, y: 6)

            Spacer()

            Button {
                isLeaving = true
                Task {
                    try? await TripRoomService.shared.leave(code: membership.code)
                    onLeave()
                }
            } label: {
                Text("退出する")
                    .font(.handCaption)
                    .foregroundStyle(Color.inkSub)
            }
            .disabled(isLeaving)
        }
        .padding(24)
        .background(Color.appBackground)
        .task(id: membership.code) {
            observer.start(code: membership.code)
        }
        .onChange(of: observer.room) { _, room in
            if let room, room.status == .started, let plan = room.plan {
                onPlanReady(plan)
            }
        }
    }
}
