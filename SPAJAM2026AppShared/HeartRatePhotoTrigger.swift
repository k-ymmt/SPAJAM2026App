//
//  HeartRatePhotoTrigger.swift
//  SPAJAM2026App
//
//  Shared between the app and the widget extension.
//

import Foundation

/// Decides when the "写真を撮りませんか？" prompt should be shown based on the heart rate.
///
/// The prompt turns on once the heart rate reaches `threshold` and stays on until it
/// drops back below `threshold - hysteresis`, so a reading oscillating around the
/// threshold does not flicker the badge.
struct HeartRatePhotoTrigger: Codable, Hashable {
    /// Heart rate (bpm) at or above which the prompt is shown.
    var threshold: Double
    /// How far (bpm) the heart rate must fall below `threshold` before the prompt hides.
    var hysteresis: Double
    var isEnabled: Bool

    static let thresholdRange: ClosedRange<Double> = 60...200
    static let defaultThreshold: Double = 120

    init(threshold: Double = defaultThreshold, hysteresis: Double = 10, isEnabled: Bool = true) {
        self.threshold = min(max(threshold, Self.thresholdRange.lowerBound), Self.thresholdRange.upperBound)
        self.hysteresis = max(hysteresis, 0)
        self.isEnabled = isEnabled
    }

    /// Lower bound below which an active prompt is hidden again.
    var releaseThreshold: Double { threshold - hysteresis }

    /// Returns the new prompt state given the previous state and the latest reading.
    func shouldShowPrompt(wasShowing: Bool, heartRate: Double?) -> Bool {
        guard isEnabled, let heartRate, heartRate.isFinite else { return false }
        if wasShowing {
            return heartRate > releaseThreshold
        }
        return heartRate >= threshold
    }
}
