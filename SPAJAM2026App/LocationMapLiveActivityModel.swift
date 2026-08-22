//
//  LocationMapLiveActivityModel.swift
//  SPAJAM2026App
//

import ActivityKit
import CoreLocation
import Foundation
import MapKit
import Observation
import UIKit

/// Tracks the device location in the background, renders a map snapshot of it with
/// `MKMapSnapshotter`, stores the image in the App Group container and pushes the
/// result to a Live Activity.
///
/// Widget extensions cannot render `Map`, so a static image is the only way to show
/// a map inside a Live Activity.
@MainActor
@Observable
final class LocationMapLiveActivityModel: NSObject {
    typealias Attributes = LocationMapActivityAttributes

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    // MARK: Settings
    /// Minimum seconds between two snapshot updates.
    var minimumUpdateInterval: TimeInterval = 20
    /// Minimum distance (m) the device must move before a new snapshot is rendered.
    var minimumDistance: CLLocationDistance = 30
    /// Side length of the map region shown in the snapshot (m).
    var regionSpan: CLLocationDistance = 600
    var title = "現在地を追跡中"

    // MARK: Runtime
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var activity: Activity<Attributes>?
    private(set) var lastLocation: CLLocation?
    private(set) var lastSnapshot: UIImage?
    private(set) var isRenderingSnapshot = false
    private(set) var log: [LogEntry] = []
    private(set) var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var isTracking: Bool { activity != nil }

    private let locationManager = CLLocationManager()
    private var lastSnapshotLocation: CLLocation?
    private var lastSnapshotDate: Date?
    private var updateCount = 0
    private var pendingLocation: CLLocation?
    private var observationTask: Task<Void, Never>?

    /// Snapshot size in points. Kept small: the lock screen presentation is ~160pt tall and
    /// the widget extension has a tight memory budget.
    private let snapshotSize = CGSize(width: 360, height: 150)

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .otherNavigation

        // Re-attach to an activity that survived an app relaunch.
        if let existing = Activity<Attributes>.activities.first {
            activity = existing
            updateCount = existing.content.state.updateCount
            observe(existing)
            append("既存の Live Activity に再接続: \(existing.id.prefix(8))…")
        }
    }

    // MARK: - Permissions

    func requestAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Escalate so updates keep flowing while the app is in the background.
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    // MARK: - Start / stop

    func start() {
        let info = ActivityAuthorizationInfo()
        areActivitiesEnabled = info.areActivitiesEnabled
        guard info.areActivitiesEnabled else {
            append("Live Activities が無効です(設定アプリで有効にしてください)")
            return
        }
        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            append("位置情報の許可がありません")
            requestAuthorization()
            return
        }
        guard activity == nil else { return }

        do {
            try prepareDirectory()
            let state = Attributes.ContentState(
                imageFileName: nil,
                latitude: lastLocation?.coordinate.latitude ?? 0,
                longitude: lastLocation?.coordinate.longitude ?? 0,
                accuracy: lastLocation?.horizontalAccuracy ?? 0,
                updatedAt: .now,
                updateCount: 0
            )
            let activity = try Activity.request(
                attributes: Attributes(title: title),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            self.activity = activity
            updateCount = 0
            lastSnapshotLocation = nil
            lastSnapshotDate = nil
            observe(activity)
            append("開始: id=\(activity.id.prefix(8))…")

            locationManager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.startUpdatingLocation()
            if let lastLocation {
                Task { await renderAndUpdate(for: lastLocation, force: true) }
            }
        } catch {
            append("開始に失敗: \(error.localizedDescription)")
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        guard let activity else { return }
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                               dismissalPolicy: .default)
            append("終了: id=\(activity.id.prefix(8))…")
            self.activity = nil
            observationTask?.cancel()
            observationTask = nil
        }
    }

    /// Renders a snapshot immediately, ignoring the throttling thresholds.
    func forceUpdate() {
        guard let location = lastLocation else {
            append("位置情報がまだ取得できていません")
            return
        }
        Task { await renderAndUpdate(for: location, force: true) }
    }

    func clearLog() { log.removeAll() }

    // MARK: - Snapshot pipeline

    private func shouldRender(for location: CLLocation) -> Bool {
        guard let lastSnapshotLocation, let lastSnapshotDate else { return true }
        let elapsed = Date.now.timeIntervalSince(lastSnapshotDate)
        let moved = location.distance(from: lastSnapshotLocation)
        return elapsed >= minimumUpdateInterval && moved >= minimumDistance
    }

    private func renderAndUpdate(for location: CLLocation, force: Bool) async {
        guard let activity else { return }
        guard force || shouldRender(for: location) else { return }
        if isRenderingSnapshot {
            // Coalesce: keep the newest location and render it after the current one.
            pendingLocation = location
            return
        }
        isRenderingSnapshot = true
        defer { isRenderingSnapshot = false }

        do {
            let image = try await renderSnapshot(for: location)
            let fileName = try save(image)
            updateCount += 1
            let state = Attributes.ContentState(
                imageFileName: fileName,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                updatedAt: .now,
                updateCount: updateCount
            )
            await activity.update(ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(180)))
            lastSnapshot = image
            lastSnapshotLocation = location
            lastSnapshotDate = .now
            append(String(format: "更新 #%d: %.5f, %.5f (±%.0fm)",
                          updateCount, location.coordinate.latitude, location.coordinate.longitude,
                          location.horizontalAccuracy))
        } catch {
            append("スナップショット失敗: \(error.localizedDescription)")
        }

        if let next = pendingLocation {
            pendingLocation = nil
            await renderAndUpdate(for: next, force: false)
        }
    }

    private func renderSnapshot(for location: CLLocation) async throws -> UIImage {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: location.coordinate,
                                            latitudinalMeters: regionSpan,
                                            longitudinalMeters: regionSpan)
        options.size = snapshotSize
        options.scale = UIScreen.main.scale
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let point = snapshot.point(for: location.coordinate)

        // Draw the current-location dot on top of the map tile image.
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size,
                                               format: snapshot.image.imageRendererFormat)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext

            // Accuracy circle (clamped so it stays visible but not overwhelming).
            let metersPerPoint = regionSpan / Double(snapshotSize.width)
            let radius = min(max(location.horizontalAccuracy / metersPerPoint, 12), 60)
            cg.setFillColor(UIColor.systemBlue.withAlphaComponent(0.18).cgColor)
            cg.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius,
                                      width: radius * 2, height: radius * 2))

            let dot = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
            cg.setFillColor(UIColor.white.cgColor)
            cg.fillEllipse(in: dot)
            cg.setFillColor(UIColor.systemBlue.cgColor)
            cg.fillEllipse(in: dot.insetBy(dx: 3, dy: 3))
        }
    }

    private func prepareDirectory() throws {
        guard let dir = MapSnapshotStore.directoryURL else {
            throw SnapshotError.noAppGroup
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Writes the image with a fresh name (so the widget never reads a half-written file)
    /// and removes older snapshots.
    private func save(_ image: UIImage) throws -> String {
        guard let dir = MapSnapshotStore.directoryURL else { throw SnapshotError.noAppGroup }
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw SnapshotError.encoding }
        let fileName = "snapshot-\(Int(Date.now.timeIntervalSince1970 * 1000)).jpg"
        try data.write(to: dir.appending(path: fileName), options: .atomic)

        let fm = FileManager.default
        for old in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where old != fileName {
            try? fm.removeItem(at: dir.appending(path: old))
        }
        return fileName
    }

    enum SnapshotError: LocalizedError {
        case noAppGroup, encoding

        var errorDescription: String? {
            switch self {
            case .noAppGroup: "App Group コンテナにアクセスできません"
            case .encoding: "画像のエンコードに失敗しました"
            }
        }
    }

    // MARK: - Observation

    private func observe(_ activity: Activity<Attributes>) {
        observationTask?.cancel()
        observationTask = Task { [weak self] in
            for await state in activity.activityStateUpdates {
                await MainActor.run {
                    self?.append("状態変化: \(String(describing: state))")
                    if state == .dismissed || state == .ended {
                        self?.locationManager.stopUpdatingLocation()
                        self?.activity = nil
                    }
                }
            }
        }
    }

    private func append(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 100 { log.removeLast(log.count - 100) }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationMapLiveActivityModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            append("位置情報の許可: \(status.label)")
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.allowsBackgroundLocationUpdates = status == .authorizedAlways
                // Get a first fix right away so the activity can start with a map.
                locationManager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastLocation = location
            await renderAndUpdate(for: location, force: false)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            append("位置情報エラー: \(error.localizedDescription)")
        }
    }
}

extension CLAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined: "未決定"
        case .restricted: "制限あり"
        case .denied: "拒否"
        case .authorizedAlways: "常に許可"
        case .authorizedWhenInUse: "使用中のみ許可"
        @unknown default: "不明"
        }
    }
}
