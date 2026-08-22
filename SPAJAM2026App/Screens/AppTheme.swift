//
//  AppTheme.swift
//  SPAJAM2026App
//
//  Figma デザイン(docs/Figma)の共通部品。
//  - BrushButton: 筆でひと塗りしたような主要 CTA(Group 302 画像)
//  - OutlineButton: 白地+枠線の二次ボタン
//  - HandFrameRow: 手書き風フレーム(Vector 22 画像)を背景にしたリスト行
//  - CategoryBadge: ミッションカテゴリのバッジ
//

import SwiftUI

/// 主要 CTA。筆致シェイプの画像を背景にした塗りボタン
struct BrushButton: View {
    let label: String
    var loading = false
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white) }
                Text(label)
                    .font(.handHeadline)
                    .foregroundStyle(.white)
                    // こよみゆるは太字面がないため、同色シャドウで線を太らせる
                    .shadow(color: .white.opacity(0.8), radius: 0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                Image("BrushButton")
                    .resizable(resizingMode: .stretch)
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled && !loading ? 0.45 : 1)
    }
}

/// 二次ボタン。白地カプセル+枠線
struct OutlineButton: View {
    let label: String
    var tint: Color = .inkSub
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.handBody)
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(.white, in: Capsule())
                .overlay(Capsule().stroke(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// 手書き風フレームを背景にしたミッションリスト行
struct HandFrameRow<Content: View>: View {
    var minHeight: CGFloat = 84
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background {
                Image("HandFrame")
                    .resizable(
                        capInsets: EdgeInsets(top: 26, leading: 40, bottom: 26, trailing: 40),
                        resizingMode: .stretch
                    )
            }
    }
}

/// ミッションカテゴリのバッジ。達成時はティール塗り+チェック
struct CategoryBadge: View {
    let label: String
    var achieved = false

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
            if achieved {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
            }
        }
        .font(.handCaption2.bold())
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(achieved ? Color.appAccent : Color.badgeBackground, in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(achieved ? .white : Color.badgeText)
    }
}
