//
//  TripNotifier.swift
//  SPAJAM2026App
//
//  旅行中のローカル通知(接近・心拍上昇・メンバー達成)。
//  シールド中でスマホを見ていない前提なので、Watch 触覚とセットで
//  ロック画面にも同じイベントを残す。フォアグラウンドでもバナー表示する。
//

import Foundation
import UserNotifications

@MainActor
final class TripNotifier: NSObject {
    static let shared = TripNotifier()

    /// 同種イベントの通知間隔(スパム防止)
    private let cooldown: TimeInterval = 120
    private var lastSentAt: [String: Date] = [:]
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    /// 旅行開始時に一度だけ呼ぶ
    func requestAuthorization() async {
        let status = await center.notificationSettings().authorizationStatus
        guard status == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// kind ごとのクールダウンを守って即時通知する
    func post(kind: String, title: String, body: String) {
        if let last = lastSentAt[kind], Date().timeIntervalSince(last) < cooldown { return }
        lastSentAt[kind] = Date()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        center.add(UNNotificationRequest(
            identifier: "trip.\(kind).\(UUID().uuidString)",
            content: content,
            trigger: nil
        ))
    }
}

extension TripNotifier: UNUserNotificationCenterDelegate {
    /// アプリが前面でもバナー表示する
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
