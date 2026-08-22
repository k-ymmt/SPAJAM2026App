//
//  ProfileSetupView.swift
//  SPAJAM2026App
//
//  初回起動時のなまえ登録(00 系デザインの軽量版)。
//  アカウント登録は行わず(匿名認証のまま)、旅で使う表示名だけを保存する。
//

import SwiftUI

struct ProfileSetupView: View {
    var onComplete: () -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)

            VStack(spacing: 8) {
                Text("はじめまして!")
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.65), radius: 0.5)
                Text("旅で使うなまえを教えてね")
                    .font(.handCaption)
                    .foregroundStyle(Color.inkSub)
            }

            TextField("例: たろう", text: $name)
                .font(.system(size: 17))
                .foregroundStyle(Color.inkMain)
                .multilineTextAlignment(.center)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 1))
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { saveIfPossible() }

            Spacer()

            BrushButton(label: "はじめる", disabled: trimmedName.isEmpty) {
                saveIfPossible()
            }
        }
        .padding(24)
        .background(Color.appBackground)
        .onAppear { isFocused = true }
    }

    private func saveIfPossible() {
        guard !trimmedName.isEmpty else { return }
        UserProfileStore.name = trimmedName
        onComplete()
    }
}

#Preview {
    ProfileSetupView(onComplete: {})
}
