//
//  ScreenHeader.swift
//  SPAJAM2026App
//
//  全画面共通のヘッダ。タイトル(handLargeTitle)+サブタイトル(handCaption)+
//  右上アクセサリ(歯車など)。高さ・余白を統一する。
//

import SwiftUI

struct ScreenHeader<Accessory: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var accessory: () -> Accessory

    init(_ title: String, subtitle: String? = nil, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.inkMain)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let subtitle {
                    Text(subtitle)
                        .font(.handCaption)
                        .foregroundStyle(Color.inkSub)
                }
            }
            Spacer(minLength: 0)
            accessory()
        }
        .frame(minHeight: 64, alignment: .topLeading)
        .padding(.top, 4)
    }
}

extension ScreenHeader where Accessory == EmptyView {
    init(_ title: String, subtitle: String? = nil) {
        self.init(title, subtitle: subtitle) { EmptyView() }
    }
}

/// ヘッダ右上の丸ボタン(歯車など)の統一スタイル
struct HeaderIconButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.inkSub)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
        }
    }
}
