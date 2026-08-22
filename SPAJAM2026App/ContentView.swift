//
//  ContentView.swift
//  SPAJAM2026App
//
//  ルートフロー: エリア選択 → プラン確認 → 旅行中(ミッション実施) → リザルト(→ 旅くらべ)
//

import SwiftUI

struct ContentView: View {
    @State private var session: TripSession?

    var body: some View {
        Group {
            if let session {
                Group {
                    switch session.phase {
                    case .planning:
                        PlanView { session.startTrip() }
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
    }
}

#Preview {
    ContentView()
}
