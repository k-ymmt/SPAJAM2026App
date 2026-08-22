//
//  RestrictionSetupView.swift
//  SPAJAM2026App
//
//  06 制限設定(おやすみにするアプリ)。カテゴリごとのトグルで選ぶ。
//  Family Controls の実際の選択はシステム UI(FamilyActivityPicker)必須のため、
//  トグルは「推奨セットの ON/OFF 表現」で、細かい選択はピッカーに委ねる。
//  実機 + Family Controls が使えない環境では「制限なしではじめる」だけが機能する。
//  デザイン: docs/mission-design.pen「06 制限設定(おやすみ設定)」
//

import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

/// トグルで表現するシールド対象カテゴリ(見た目の仕様。実際の対象はピッカーの選択)
private struct ShieldCategory: Identifiable {
    let id: String
    let label: String
    let detail: String
    let symbol: String
    var defaultOn: Bool = true
}

struct RestrictionSetupView: View {
    @Environment(TripSession.self) private var session
    var onStart: () -> Void
    @State private var showPicker = false
    @State private var toggles: [String: Bool] = [:]

    private let categories: [ShieldCategory] = [
        ShieldCategory(id: "sns", label: "SNS", detail: "Instagram, X など", symbol: "bubble.left.fill"),
        ShieldCategory(id: "game", label: "ゲーム", detail: "ゲームカテゴリすべて", symbol: "gamecontroller.fill"),
        ShieldCategory(id: "video", label: "動画", detail: "YouTube, TikTok など", symbol: "play.rectangle.fill"),
        ShieldCategory(id: "photo", label: "写真アルバム", detail: "標準の写真アプリ", symbol: "photo.fill"),
        ShieldCategory(id: "phone", label: "電話", detail: "緊急連絡のため OFF を推奨", symbol: "phone.fill", defaultOn: false),
        ShieldCategory(id: "browser", label: "ブラウザ", detail: "Safari, Chrome など", symbol: "globe"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader("おやすみにするアプリ", subtitle: "旅行中にシールドするアプリを選べます。ミッションのカメラはいつでも使えます")

                ForEach(categories) { category in
                    categoryRow(category)
                }

                Button {
                    Task {
                        await session.shield.requestAuthorization()
                        if session.shield.isAuthorized { showPicker = true }
                    }
                } label: {
                    Label(
                        session.shield.hasSelection ? "えらんだアプリをかえる(選択済み)" : "アプリを細かくえらぶ(システム画面)",
                        systemImage: "moon.zzz.fill"
                    )
                    .font(.handCaption.bold())
                    .foregroundStyle(Color.badgeText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.badgeBackground, in: Capsule())
                }
                .buttonStyle(.plain)

                startButton
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color.appBackground)
        .onAppear {
            if toggles.isEmpty {
                toggles = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0.defaultOn) })
            }
        }
        #if canImport(FamilyControls)
        .familyActivityPicker(isPresented: $showPicker, selection: Bindable(session.shield).selection)
        #endif
    }

    private func categoryRow(_ category: ShieldCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.inkSub)
                .frame(width: 40, height: 40)
                .background(Color.appBackground, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                Text(category.label)
                    .font(.handBody.bold())
                    .foregroundStyle(Color.inkMain)
                Text(category.detail)
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            Spacer()
            Toggle("", isOn: binding(for: category))
                .labelsHidden()
                .tint(.appAccent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func binding(for category: ShieldCategory) -> Binding<Bool> {
        Binding(
            get: { toggles[category.id] ?? category.defaultOn },
            set: { toggles[category.id] = $0 }
        )
    }

    private var startButton: some View {
        VStack(spacing: 10) {
            BrushButton(
                label: session.shield.hasSelection ? "この設定で旅をはじめる" : "制限なしで旅をはじめる",
                action: onStart
            )
            Text("電話は緊急連絡のため制限しないことをおすすめします")
                .font(.handCaption2)
                .foregroundStyle(Color.inkSub)
                .frame(maxWidth: .infinity)
        }
    }
}
