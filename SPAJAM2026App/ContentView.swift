//
//  ContentView.swift
//  SPAJAM2026App
//
//  ルートフロー: エリア選択 → プラン確認 → 旅行中(ミッション実施) → リザルト(→ 旅くらべ)
//  端末を振るとデバッグメニュー(フレームワークお試し)がシートで開く。
//

import SwiftUI

struct ContentView: View {
    @State private var session: TripSession?
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
                        ResultView { self.session = nil }
                    }
                }
                .environment(session)
            } else {
                AreaSelectView { plan in
                    session = TripSession(plan: plan)
                }
            }
        }
        .animation(.default, value: session == nil)
        // デザインはライト(クリーム背景)前提のため、ダークモードでも表示を固定する
        .preferredColorScheme(.light)
        .onChange(of: scenePhase) { _, newPhase in
            session?.noteScenePhase(active: newPhase == .active)
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
