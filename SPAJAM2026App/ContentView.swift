//
//  ContentView.swift
//  SPAJAM2026App
//
//  ルートフロー: エリア選択 → プラン確認 → 旅行中(ミッション実施) → リザルト(→ 旅くらべ)
//  端末を振るとデバッグメニュー(フレームワークお試し)がシートで開く。
//

import SwiftUI

struct ContentView: View {
    @State private var session: TripSession? = TripSession.restore()
    /// 招待コードで参加し、親のプラン公開を待っている状態(子)
    @State private var pendingJoin: RoomMembership? = PendingJoinStore.load()
    @State private var isDebugMenuPresented = false
    @State private var showAreaSelect = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let session {
                Group {
                    switch session.phase {
                    case .planning:
                        PlanView { session.proceedToRestrictionSetup() }
                    case .restrictionSetup:
                        RestrictionSetupView { session.startTrip() }
                    case .traveling:
                        TripMainView()
                    case .finished:
                        ResultView {
                            session.discard()
                            self.session = nil
                            showAreaSelect = false
                        }
                    }
                }
                .environment(session)
            } else if let pendingJoin {
                WaitingForPlanView(membership: pendingJoin) { plan in
                    // 親が「旅をはじめる」を押した: 子はプラン確認を飛ばしておやすみ設定へ
                    let new = TripSession(plan: plan, membership: pendingJoin)
                    new.proceedToRestrictionSetup()
                    PendingJoinStore.clear()
                    self.pendingJoin = nil
                    session = new
                } onLeave: {
                    PendingJoinStore.clear()
                    self.pendingJoin = nil
                }
            } else if showAreaSelect {
                AreaSelectView { plan, membership in
                    let new = TripSession(plan: plan, membership: membership)
                    new.persist()
                    session = new
                } onJoinedRoom: { membership in
                    PendingJoinStore.save(membership)
                    pendingJoin = membership
                }
            } else {
                HomeView { showAreaSelect = true }
            }
        }
        .animation(.default, value: session == nil)
        .animation(.default, value: pendingJoin)
        .animation(.default, value: showAreaSelect)
        // デザインはライト(クリーム背景)前提のため、ダークモードでも表示を固定する
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, newPhase in
            session?.noteScenePhase(active: newPhase == .active)
        }
        // デバッグメニューで保存セッションを書き換え/クリアしたら、その内容でセッションを作り直す
        .onReceive(NotificationCenter.default.publisher(for: TripSessionStore.didChange)) { _ in
            session = TripSession.restore()
        }
        .onShake {
            isDebugMenuPresented = true
        }
        .sheet(isPresented: $isDebugMenuPresented) {
            DebugMenuView()
        }
    }
}

#Preview {
    ContentView()
}
