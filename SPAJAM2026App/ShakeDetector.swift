//
//  ShakeDetector.swift
//  SPAJAM2026App
//
//  端末のシェイクを検知して通知を飛ばす。デバッグメニューの表示トリガーに使う。
//

import SwiftUI
import UIKit

extension Notification.Name {
    /// 端末が振られたときに投稿される通知。
    static let deviceDidShake = Notification.Name("SPAJAM2026App.deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

extension View {
    /// 端末が振られたときに `action` を実行する。
    func onShake(perform action: @escaping () -> Void) -> some View {
        onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            action()
        }
    }
}
