//
//  TrialActivityAttributes.swift
//  SPAJAM2026App
//
//  Shared between the app and the widget extension.
//

import ActivityKit
import SwiftUI

/// Attributes for the Live Activity trial. Static values are fixed at `request` time,
/// everything in `ContentState` can be changed with `update`.
struct TrialActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Free text shown as the main status line.
        var statusText: String
        /// Emoji shown in the compact / minimal Dynamic Island presentations.
        var emoji: String
        /// 0...1, used by the `.progress` layout.
        var progress: Double
        /// End date of the countdown, used by the `.timer` layout.
        var timerEnd: Date?
        /// Which lock screen / expanded layout to render.
        var layout: Layout
        /// Whether the activity shows an interactive "advance" button.
        var showsButton: Bool
    }

    enum Layout: String, Codable, Hashable, CaseIterable, Identifiable {
        case progress
        case timer
        case plain

        var id: String { rawValue }

        var label: String {
            switch self {
            case .progress: "プログレスバー"
            case .timer: "カウントダウン"
            case .plain: "テキストのみ"
            }
        }
    }

    enum Accent: String, Codable, Hashable, CaseIterable, Identifiable {
        case blue, green, orange, red, purple, pink

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue: .blue
            case .green: .green
            case .orange: .orange
            case .red: .red
            case .purple: .purple
            case .pink: .pink
            }
        }
    }

    var title: String
    var subtitle: String
    var accent: Accent
}
