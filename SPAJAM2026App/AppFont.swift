//
//  AppFont.swift
//  SPAJAM2026App
//
//  手書きフォントのセマンティックスタイル。
//  見出し = Hetakawa Free(へたかわ)、本文 = こよみゆる。
//

import SwiftUI

extension Font {
    // Hetakawa Free は漢字非対応のため、日本語はすべて「こよみゆる」を使う。
    // Hetakawa は数字・英字(スコア、MISSION 表記など)専用。
    private static let hetakawa = "HetakawaFree-Regular"
    private static let koyomi = "koyomiyuru"

    /// 画面タイトルなど最上位の見出し(太字)
    static let handLargeTitle = Font.custom(koyomi, size: 29).bold()
    /// セクション見出し・ミッションタイトル(太字)
    static let handTitle = Font.custom(koyomi, size: 23).bold()
    /// ボタン・強調テキスト(太字)
    static let handHeadline = Font.custom(koyomi, size: 18).bold()
    /// 本文
    static let handBody = Font.custom(koyomi, size: 16)
    /// 補足
    static let handCaption = Font.custom(koyomi, size: 14)
    /// 最小の注釈
    static let handCaption2 = Font.custom(koyomi, size: 13)
    /// スコアなどの特大数字・英字(Hetakawa は数字/英字のみ対応)
    static func handNumber(_ size: CGFloat) -> Font { .custom(hetakawa, size: size).bold() }
}

extension Color {
    /// 手書きフォントの可読性を保つ濃いめの文字色
    static let inkMain = Color(red: 0.14, green: 0.12, blue: 0.10)
    /// セカンダリ文字(.secondary より濃くして読みやすく)
    static let inkSub = Color(red: 0.36, green: 0.33, blue: 0.27)
}
