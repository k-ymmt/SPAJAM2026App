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
                        MissionCameraView()
                    case .finished:
                        ResultView {
                            session.discard()
                            self.session = nil
                        }
                    }
                }
                .environment(session)
            } else {
                AreaSelectView { plan in
                    let new = TripSession(plan: plan)
                    new.persist()
                    session = new
                }
            }
        }
        .animation(.default, value: session == nil)
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
