//
//  TripMainView.swift
//  SPAJAM2026App
//
//  旅行中のメイン画面 = ミッション一覧。タップでミッション実施(カメラ)を全画面で開く。
//

import SwiftUI

struct TripMainView: View {
    @Environment(TripSession.self) private var session
    @State private var showCamera = false
    @State private var showRestrictionAdjust = false
    @State private var confirmEnd = false

    var body: some View {
        TripMissionListView(
            onSelectMission: { mission in
                session.selectMission(mission)
                showCamera = true
            },
            onOpenSettings: { showRestrictionAdjust = true },
            onEndTrip: { confirmEnd = true }
        )
        .fullScreenCover(isPresented: $showCamera) {
            MissionCameraView()
                .environment(session)
        }
        .sheet(isPresented: $showRestrictionAdjust) {
            RestrictionAdjustView()
                .environment(session)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("旅をおわりますか?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("旅をおわってリザルトへ", role: .destructive) {
                session.endTrip()
            }
            Button("つづける", role: .cancel) {}
        }
    }
}
