//
//  MissionActivityAttributes.swift
//  SPAJAM2026App
//
//  Shared between the app and the widget extension.
//

import ActivityKit
import Foundation

/// "TABI MISSION" Live Activity: shows the next mission, the distance from a chosen
/// landmark, the current heart rate and a segmented progress indicator.
struct MissionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// "ミッション 2/5" → 2
        var missionNumber: Int
        /// "ミッション 2/5" → 5
        var missionTotal: Int
        /// The NEXT MISSION body text.
        var missionText: String
        /// Name of the landmark the distance is measured from ("雷門").
        var landmarkName: String
        /// Distance from the landmark to the current location, in meters. `nil` until a fix exists.
        var distanceMeters: Double?
        /// Latest heart rate in bpm. `nil` until a reading arrives.
        var heartRate: Double?
        /// Segmented bar at the bottom of the card.
        var indicator: MissionIndicator
        var updatedAt: Date

        var missionCounterText: String { "ミッション \(missionNumber)/\(missionTotal)" }
        var distanceText: String { MissionDistanceFormat.label(landmark: landmarkName, meters: distanceMeters) }
        var heartRateText: String {
            heartRate.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm"
        }
    }

    /// Small label next to the icon ("TABI MISSION").
    var brandName: String
    /// SF Symbol drawn in the top-left tile.
    var iconSymbol: String
}

/// Segmented indicator: `completedCount` bright segments, then an optional dimmed
/// "active" segment, then pending segments.
struct MissionIndicator: Codable, Hashable {
    enum Segment: Hashable {
        case completed, active, pending
    }

    var segmentCount: Int
    var completedCount: Int
    /// Whether the segment right after the completed ones is highlighted as in-progress.
    var highlightsActive: Bool

    init(segmentCount: Int = 5, completedCount: Int = 0, highlightsActive: Bool = true) {
        self.segmentCount = max(segmentCount, 1)
        self.completedCount = min(max(completedCount, 0), self.segmentCount)
        self.highlightsActive = highlightsActive
    }

    func segment(at index: Int) -> Segment {
        if index < completedCount { return .completed }
        if highlightsActive, index == completedCount, index < segmentCount { return .active }
        return .pending
    }

    var segments: [Segment] { (0..<segmentCount).map(segment(at:)) }
}

enum MissionDistanceFormat {
    /// "雷門から 120m" / "雷門から 1.2km" / "雷門から --".
    static func label(landmark: String, meters: Double?) -> String {
        "\(landmark)から \(distance(meters))"
    }

    static func distance(_ meters: Double?) -> String {
        guard let meters, meters.isFinite, meters >= 0 else { return "--" }
        if meters < 1000 {
            return "\(Int(meters.rounded()))m"
        }
        let km = meters / 1000
        let text = km < 10
            ? km.formatted(.number.precision(.fractionLength(1)))
            : km.formatted(.number.precision(.fractionLength(0)))
        return "\(text)km"
    }
}
