//
//  RestrictionSetupView.swift
//  SPAJAM2026App
//
//  06 制限設定(おやすみ設定)。旅行中にシールドするアプリを選ぶ。
//  実機 + Family Controls が使えない環境では「制限なしではじめる」だけが機能する。
//  デザイン: docs/mission-design.pen「06 制限設定(おやすみ設定)」
//

import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct RestrictionSetupView: View {
    @Environment(TripSession.self) private var session
    var onStart: () -> Void
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("おやすみにするアプリ")
                    .font(.handLargeTitle)
                Text("旅行中にシールドするアプリを選べます。ミッションのカメラはいつでも使えます")
                    .font(.handCaption)
                    .foregroundStyle(Color.inkSub)
            }

            statusCard

            Button {
                Task {
                    await session.shield.requestAuthorization()
                    if session.shield.isAuthorized { showPicker = true }
                }
            } label: {
                Label("おやすみにするアプリを選ぶ", systemImage: "moon.zzz.fill")
                    .font(.handHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.teal)

            Spacer()

            VStack(spacing: 10) {
                Button(action: onStart) {
                    Text(session.shield.hasSelection ? "この設定で旅をはじめる" : "制限なしで旅をはじめる")
                        .font(.handHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Text("電話は緊急連絡のため制限しないことをおすすめします")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
        #if canImport(FamilyControls)
        .familyActivityPicker(isPresented: $showPicker, selection: Bindable(session.shield).selection)
        #endif
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: session.shield.hasSelection ? "checkmark.shield.fill" : "shield.slash")
                .font(.handTitle)
                .foregroundStyle(session.shield.hasSelection ? .teal : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.shield.hasSelection ? "シールド設定済み" : "まだ何も選ばれていません")
                    .font(.handHeadline)
                Text(session.shield.isAuthorized
                     ? "旅行を開始すると選んだアプリがおやすみになります"
                     : "スクリーンタイムの許可が必要です(実機のみ)")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            Spacer()
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
}
