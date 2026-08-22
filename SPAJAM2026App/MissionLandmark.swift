//
//  MissionLandmark.swift
//  SPAJAM2026App
//

import CoreLocation
import Foundation

/// A reference point the mission distance is measured from.
nonisolated struct MissionLandmark: Identifiable, Hashable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double

    var id: String { name }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }

    func distance(to location: CLLocation) -> CLLocationDistance {
        self.location.distance(from: location)
    }

    /// Asakusa area presets.
    static let presets: [MissionLandmark] = [
        MissionLandmark(name: "雷門", latitude: 35.71100, longitude: 139.79645),
        MissionLandmark(name: "仲見世", latitude: 35.71270, longitude: 139.79660),
        MissionLandmark(name: "浅草寺", latitude: 35.71478, longitude: 139.79665),
        MissionLandmark(name: "浅草花やしき", latitude: 35.71550, longitude: 139.79430),
        MissionLandmark(name: "隅田公園", latitude: 35.71300, longitude: 139.80100),
        MissionLandmark(name: "東京スカイツリー", latitude: 35.71006, longitude: 139.81070),
    ]
}
