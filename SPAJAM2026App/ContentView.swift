//
//  ContentView.swift
//  SPAJAM2026App
//
//  ルートフロー: プラン確認 → 旅行中(ミッション実施) → リザルト
//

import SwiftUI

struct ContentView: View {
    @State private var session = TripSession()

    var body: some View {
        Group {
            switch session.phase {
            case .planning:
                PlanView { session.startTrip() }
            case .traveling:
                MissionCameraView()
            case .finished:
                ResultView { session = TripSession() }
            }
        }
        .environment(session)
        .animation(.default, value: session.phase == .traveling)
    }
}

#Preview {
    ContentView()
}
