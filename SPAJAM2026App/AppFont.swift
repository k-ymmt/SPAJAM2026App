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

    /// 画面タイトルなど最上位の見出し
    static let handLargeTitle = Font.custom(koyomi, size: 28)
    /// セクション見出し・ミッションタイトル
    static let handTitle = Font.custom(koyomi, size: 22)
    /// ボタン・強調テキスト
    static let handHeadline = Font.custom(koyomi, size: 18)
    /// 本文
    static let handBody = Font.custom(koyomi, size: 16)
    /// 補足
    static let handCaption = Font.custom(koyomi, size: 13)
    /// 最小の注釈
    static let handCaption2 = Font.custom(koyomi, size: 12)
    /// スコアなどの特大数字・英字(Hetakawa は数字/英字のみ対応)
    static func handNumber(_ size: CGFloat) -> Font { .custom(hetakawa, size: size) }
}
