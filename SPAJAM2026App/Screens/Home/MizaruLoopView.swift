//
//  MizaruLoopView.swift
//  SPAJAM2026App
//
//  TOP 画面のミザルのループアニメーション。
//  素材の mizaru-loop.mp4(H.264 はアルファ非対応)を透過 PNG 連番に変換して
//  バンドルし、UIImageView のフレームアニメーションで透過のままループ再生する。
//

import SwiftUI
import UIKit

struct MizaruLoopView: UIViewRepresentable {
    /// 元動画の長さ(5.04 秒)に合わせたループ周期
    var duration: TimeInterval = 5.0

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        var frames: [UIImage] = []
        var index = 0
        while let url = Bundle.main.url(forResource: String(format: "mizaru-loop-%03d", index), withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) {
            frames.append(image)
            index += 1
        }
        if frames.count > 1 {
            view.animationImages = frames
            view.animationDuration = duration
            view.startAnimating()
        } else {
            // フレームが見つからない場合は静止画にフォールバック
            view.image = UIImage(named: "MizaruCharacter")
        }
        return view
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
