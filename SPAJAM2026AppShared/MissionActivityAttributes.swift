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
        /// Whether the "写真を撮りませんか？" badge is shown (heart rate crossed the threshold).
        var showsPhotoPrompt: Bool

        init(missionNumber: Int, missionTotal: Int, missionText: String, landmarkName: String,
             distanceMeters: Double?, heartRate: Double?, indicator: MissionIndicator,
             updatedAt: Date, showsPhotoPrompt: Bool = false) {
            self.missionNumber = missionNumber
            self.missionTotal = missionTotal
            self.missionText = missionText
            self.landmarkName = landmarkName
            self.distanceMeters = distanceMeters
            self.heartRate = heartRate
            self.indicator = indicator
            self.updatedAt = updatedAt
            self.showsPhotoPrompt = showsPhotoPrompt
        }

        private enum CodingKeys: String, CodingKey {
            case missionNumber, missionTotal, missionText, landmarkName, distanceMeters, heartRate,
                 indicator, updatedAt, showsPhotoPrompt
        }

        /// `showsPhotoPrompt` is optional when decoding so activities started by an older
        /// build can still be re-attached.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            missionNumber = try c.decode(Int.self, forKey: .missionNumber)
            missionTotal = try c.decode(Int.self, forKey: .missionTotal)
            missionText = try c.decode(String.self, forKey: .missionText)
            landmarkName = try c.decode(String.self, forKey: .landmarkName)
            distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
            heartRate = try c.decodeIfPresent(Double.self, forKey: .heartRate)
            indicator = try c.decode(MissionIndicator.self, forKey: .indicator)
            updatedAt = try c.decode(Date.self, forKey: .updatedAt)
            showsPhotoPrompt = try c.decodeIfPresent(Bool.self, forKey: .showsPhotoPrompt) ?? false
        }

        static let photoPromptText = "写真を撮りませんか？"

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
