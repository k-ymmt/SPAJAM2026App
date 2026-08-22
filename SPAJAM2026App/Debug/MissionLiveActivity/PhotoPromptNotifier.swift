//
//  PhotoPromptNotifier.swift
//  SPAJAM2026App
//

import Foundation
import Observation
import UserNotifications

/// Framework-independent decision of whether a "写真を撮りませんか？" notification may be sent.
struct PhotoPromptNotificationPolicy: Hashable {
    var isEnabled: Bool
    /// Minimum seconds between two notifications so repeated threshold crossings do not spam.
    var minimumInterval: TimeInterval

    static let intervalRange: ClosedRange<TimeInterval> = 0...(30 * 60)

    init(isEnabled: Bool = true, minimumInterval: TimeInterval = 5 * 60) {
        self.isEnabled = isEnabled
        self.minimumInterval = min(max(minimumInterval, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
    }

    func shouldNotify(lastSentAt: Date?, now: Date = .now) -> Bool {
        guard isEnabled else { return false }
        guard let lastSentAt else { return true }
        return now.timeIntervalSince(lastSentAt) >= minimumInterval
    }
}

/// Sends the local notification that accompanies the Live Activity badge and shows it as a
/// banner even while the app is in the foreground.
@MainActor
@Observable
final class PhotoPromptNotifier: NSObject {
    static let shared = PhotoPromptNotifier()

    static let categoryIdentifier = "photoPrompt"
    static let requestIdentifier = "photoPrompt.heartRate"

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var lastSentAt: Date?
    private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.categoryIdentifier, actions: [], intentIdentifiers: [])
        ])
        Task { await refreshAuthorization() }
    }

    func refreshAuthorization() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Asks for permission once; returns whether notifications can be shown.
    @discardableResult
    func requestAuthorization() async -> Bool {
        await refreshAuthorization()
        if authorizationStatus == .notDetermined {
            do {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                lastError = error.localizedDescription
            }
            await refreshAuthorization()
        }
        return authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Sends the prompt if `policy` allows it. Returns `true` when a notification was scheduled.
    @discardableResult
    func notify(policy: PhotoPromptNotificationPolicy, heartRate: Double?, missionText: String) -> Bool {
        guard policy.shouldNotify(lastSentAt: lastSentAt) else { return false }
        let content = UNMutableNotificationContent()
        content.title = MissionActivityAttributes.ContentState.photoPromptText
        content.body = heartRate.map { "心拍が \(Int($0.rounded())) bpm に上がりました。" } ?? ""
        content.body += missionText.isEmpty ? "" : " ミッション: \(missionText)"
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: Self.requestIdentifier, content: content, trigger: nil)
        lastSentAt = .now
        lastError = nil
        Task {
            do {
                try await center.add(request)
            } catch {
                lastError = error.localizedDescription
            }
        }
        return true
    }
}

extension PhotoPromptNotifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
