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
    @State private var isDebugMenuPresented = false
    @State private var showAreaSelect = false
    /// 旅の開始/終了の切り替え演出(表示中は画面全体を覆う)
    @State private var transition: TripTransition?
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
            } else if showAreaSelect {
                AreaSelectView { plan in
                    let new = TripSession(plan: plan)
                    new.persist()
                    session = new
                }
            } else {
                HomeView { showAreaSelect = true }
            }
        }
        .overlay {
            if let transition {
                TripTransitionOverlay(transition: transition)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: session == nil)
        .animation(.default, value: showAreaSelect)
        .onChange(of: session?.phase) { oldPhase, newPhase in
            guard oldPhase != nil, let newPhase else { return }
            switch newPhase {
            case .traveling: showTransition(.started)
            case .finished: showTransition(.finished)
            default: break
            }
        }
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
            DebugMenuView(activeSession: session)
        }
    }

    /// 切り替え演出を表示し、duration 後にフェードアウトする
    private func showTransition(_ kind: TripTransition) {
        withAnimation(.easeIn(duration: 0.15)) {
            transition = kind
        }
        Task {
            try? await Task.sleep(for: .seconds(kind.duration))
            withAnimation(.easeOut(duration: 0.45)) {
                transition = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
