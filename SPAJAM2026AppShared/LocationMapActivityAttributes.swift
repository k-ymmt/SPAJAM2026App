//
//  LocationMapActivityAttributes.swift
//  SPAJAM2026App
//
//  Shared between the app and the widget extension.
//

import ActivityKit
import Foundation

/// Live Activity that shows a static map snapshot of the user's current location.
///
/// The snapshot image itself is too large for the 4KB `ContentState` limit, so it is
/// written to the App Group container by the app and only its file name is passed here.
struct LocationMapActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// File name of the snapshot inside `MapSnapshotStore.directoryURL`.
        var imageFileName: String?
        var latitude: Double
        var longitude: Double
        /// Horizontal accuracy in meters.
        var accuracy: Double
        var updatedAt: Date
        /// Number of updates since the activity started.
        var updateCount: Int
        /// Free text shown over the map. Empty hides the line.
        var message: String = ""
        /// 0...1 progress bar shown under the map. `nil` hides the bar.
        var progress: Double?
    }

    var title: String
}

/// Location of the snapshot files shared through the App Group.
enum MapSnapshotStore {
    static let appGroupIdentifier = "group.app.kymmt.SPAJAM2026App"

    static var directoryURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appending(path: "MapSnapshots", directoryHint: .isDirectory)
    }

    static func url(for fileName: String) -> URL? {
        directoryURL?.appending(path: fileName)
    }
}
