//
//  HomeView.swift
//  SPAJAM2026App
//
//  起動時のトップ画面。ロゴ(見ざる)+「旅をはじめる」+ 今までの旅のきろく。
//  デザイン: docs/Figma/起動時/旅前_起動時.png
//  過去の旅は永続化未実装のためデモデータ(実装されたら TripSessionStore の履歴に差し替え)。
//

import SwiftUI

struct HomeView: View {
    var onStart: () -> Void
    @State private var isProfilePresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // なまえの変更(アカウント)
            HStack {
                Spacer()
                HeaderIconButton(systemName: "person.crop.circle") {
                    isProfilePresented = true
                }
            }

            Spacer()

            // ロゴ(仮: 見ざるキャラ。ロゴ素材が来たら差し替え)
            VStack(spacing: 10) {
                MizaruLoopView()
                    .padding(10)
                    .frame(width: 230, height: 230)
                Text("ミザル")
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.appAccent)
            }
            .frame(maxWidth: .infinity)

            BrushButton(label: "旅をはじめる", action: onStart)
                .padding(.top, 28)

            Spacer()
        }
        .padding(24)
        .background(Color.appBackground)
        .sheet(isPresented: $isProfilePresented) {
            ProfileSetupView(isEditing: true) {
                isProfilePresented = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

}

#Preview {
    HomeView(onStart: {})
}
