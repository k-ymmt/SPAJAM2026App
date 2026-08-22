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
    // 方針: 手書きは「声」(タイトル・お題・ボタン・演出)にだけ使い、16pt 未満にはしない。
    // 補足説明・計測値など「読ませる情報」はシステムフォントで可読性を優先する。
    /// 補足(システムフォント)
    static let handCaption = Font.system(size: 14)
    /// 最小の注釈(システムフォント)
    static let handCaption2 = Font.system(size: 13)
    /// スコアなどの特大数字・英字(Hetakawa は数字/英字のみ対応)
    static func handNumber(_ size: CGFloat) -> Font { .custom(hetakawa, size: size).bold() }
}

extension Color {
    // Figma デザイン(docs/Figma)のパレット。キーカラーはティール、背景はグレイッシュグリーン。

    /// 手書きフォントの可読性を保つ濃いめの文字色(#2F3833)
    static let inkMain = Color(red: 0.184, green: 0.220, blue: 0.200)
    /// セカンダリ文字(#55605C)
    static let inkSub = Color(red: 0.333, green: 0.376, blue: 0.361)
    /// キーカラーのティール(#2A7D6C)
    static let appAccent = Color(red: 0.165, green: 0.490, blue: 0.424)
    /// キーカラーの淡色(#8FBCB0)
    static let appAccentSoft = Color(red: 0.561, green: 0.737, blue: 0.690)
    /// 画面背景(#ECEEE7)
    static let appBackground = Color(red: 0.925, green: 0.933, blue: 0.906)
    /// カテゴリバッジ背景(#E9F4E6)
    static let badgeBackground = Color(red: 0.914, green: 0.957, blue: 0.902)
    /// カテゴリバッジ文字(#3E8E41)
    static let badgeText = Color(red: 0.243, green: 0.557, blue: 0.255)
    /// カードの枠線(#DDE2D8)
    static let cardStroke = Color(red: 0.867, green: 0.886, blue: 0.847)
}
