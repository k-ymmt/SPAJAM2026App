//
//  MissionLiveActivityModel.swift
//  SPAJAM2026App
//

import ActivityKit
import CoreLocation
import Foundation
import Observation

/// Drives the "TABI MISSION" Live Activity: mission text / counter / indicator are edited
/// in the UI, the distance comes from background location updates and the heart rate from
/// `HeartRateFeed` (Apple Watch via WatchConnectivity, HealthKit as fallback).
///
/// A singleton so that a background wake-up (watch message, HealthKit delivery, location)
/// can reach the running activity even if the settings screen was never opened.
@MainActor
@Observable
final class MissionLiveActivityModel: NSObject {
    typealias Attributes = MissionActivityAttributes

    static let shared = MissionLiveActivityModel()

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    // MARK: Editable content
    var brandName = "TABI MISSION"
    var iconSymbol = "map.fill"
    static let iconChoices = ["map.fill", "map", "mappin.and.ellipse", "location.fill", "signpost.right.fill", "figure.walk"]

    var missionNumber = 2
    var missionTotal = 5
    var missionText = "仲見世で いちばん赤いものを撮る"
    var landmark: MissionLandmark = MissionLandmark.presets[0]
    var indicatorSegments = 5
    var indicatorCompleted = 1
    var indicatorHighlightsActive = true
    /// Manual heart rate used when no watch reading is available (nil = hide).
    var manualHeartRate: Double? {
        didSet { evaluatePhotoPrompt(reason: "手動心拍") }
    }
    /// Heart rate threshold that shows the "写真を撮りませんか？" badge.
    var photoTrigger = HeartRatePhotoTrigger() {
        didSet { evaluatePhotoPrompt(reason: "閾値変更") }
    }
    /// Whether the "写真を撮りませんか？" badge is currently shown.
    private(set) var showsPhotoPrompt = false

    // MARK: Runtime
    private(set) var activity: Activity<Attributes>?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var lastLocation: CLLocation?
    private(set) var lastHeartRate: HeartRateReading?
    private(set) var log: [LogEntry] = []
    private(set) var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled

    var isRunning: Bool { activity != nil }
    var currentDistance: Double? { lastLocation.map { landmark.distance(to: $0) } }

    private let locationManager = CLLocationManager()
    private let feed = HeartRateFeed.shared
    var feedStatus: HeartRateFeed { feed }
    private var feedSubscription: UUID?
    private var observationTask: Task<Void, Never>?
    private var lastPushedState: Attributes.ContentState?
    private var lastPushDate: Date?
    private var pendingPush: Task<Void, Never>?

    /// Minimum seconds between two activity updates caused by sensor data.
    var minimumUpdateInterval: TimeInterval = 5
    /// Distance change (m) needed before a sensor-driven update is pushed.
    var minimumDistanceDelta: Double = 5

    private override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 5
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .otherNavigation

        if let existing = Activity<Attributes>.activities.first {
            attach(existing)
            append("既存の Live Activity に再接続: \(existing.id.prefix(8))…")
        }
    }

    // MARK: - Permissions

    func requestAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: locationManager.requestAlwaysAuthorization()
        default: break
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
        guard activity == nil else { return }
        do {
            let activity = try Activity.request(
                attributes: Attributes(brandName: brandName, iconSymbol: iconSymbol),
                content: ActivityContent(state: makeState(), staleDate: nil),
                pushType: nil
            )
            attach(activity)
            append("開始: id=\(activity.id.prefix(8))…")
        } catch {
            append("開始に失敗: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard let activity else { return }
        detachSensors()
        Task {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                               dismissalPolicy: .default)
            append("終了: id=\(activity.id.prefix(8))…")
            self.activity = nil
        }
    }

    /// Pushes the edited content (mission, counter, indicator…) to the activity now.
    func applyContent() {
        push(force: true, reason: "表示内容を反映")
    }

    func clearLog() { log.removeAll() }

    /// Hides the photo prompt until the heart rate crosses the threshold again.
    func dismissPhotoPrompt() {
        guard showsPhotoPrompt else { return }
        showsPhotoPrompt = false
        push(force: true, reason: "写真提案を非表示")
    }

    /// Current heart rate used for the prompt decision (sensor first, manual as fallback).
    var effectiveHeartRate: Double? { lastHeartRate?.beatsPerMinute ?? manualHeartRate }

    /// Re-evaluates the prompt against the latest heart rate and pushes if it changed.
    /// Returns `true` when the prompt state changed (and an update was pushed).
    @discardableResult
    private func evaluatePhotoPrompt(reason: String) -> Bool {
        let next = photoTrigger.shouldShowPrompt(wasShowing: showsPhotoPrompt, heartRate: effectiveHeartRate)
        guard next != showsPhotoPrompt else { return false }
        showsPhotoPrompt = next
        let bpm = effectiveHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--"
        push(force: true, reason: next
             ? "写真提案を表示 (\(bpm) ≥ \(Int(photoTrigger.threshold)) bpm, \(reason))"
             : "写真提案を解除 (\(bpm) ≤ \(Int(photoTrigger.releaseThreshold)) bpm, \(reason))")
        return true
    }

    // MARK: - Sensors

    private func attach(_ activity: Activity<Attributes>) {
        self.activity = activity
        let state = activity.content.state
        missionNumber = state.missionNumber
        missionTotal = state.missionTotal
        missionText = state.missionText
        if let preset = MissionLandmark.presets.first(where: { $0.name == state.landmarkName }) {
            landmark = preset
        }
        indicatorSegments = state.indicator.segmentCount
        indicatorCompleted = state.indicator.completedCount
        indicatorHighlightsActive = state.indicator.highlightsActive
        lastPushedState = state

        observationTask?.cancel()
        observationTask = Task { [weak self] in
            for await activityState in activity.activityStateUpdates {
                await MainActor.run {
                    self?.append("状態変化: \(String(describing: activityState))")
                    if activityState == .dismissed || activityState == .ended {
                        self?.detachSensors()
                        self?.activity = nil
                    }
                }
            }
        }

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            locationManager.allowsBackgroundLocationUpdates = authorizationStatus == .authorizedAlways
            locationManager.showsBackgroundLocationIndicator = true
            locationManager.startUpdatingLocation()
        } else {
            append("位置情報の許可がないため距離は更新されません")
            requestAuthorization()
        }

        feedSubscription = feed.subscribe { [weak self] sample in
            guard let self else { return }
            lastHeartRate = sample
            let reason = "心拍 \(Int(sample.beatsPerMinute.rounded())) bpm (\(sample.source == .watch ? "Watch" : "HealthKit"))"
            // A prompt state change is pushed immediately; plain readings stay throttled.
            if !evaluatePhotoPrompt(reason: reason) {
                push(force: false, reason: reason)
            }
        }
        if let latest = feed.latest { lastHeartRate = latest }
        showsPhotoPrompt = activity.content.state.showsPhotoPrompt
        evaluatePhotoPrompt(reason: "再接続")
        Task { await feed.startHealthKit() }
    }

    private func detachSensors() {
        locationManager.stopUpdatingLocation()
        observationTask?.cancel()
        observationTask = nil
        if let feedSubscription { feed.unsubscribe(feedSubscription) }
        feedSubscription = nil
        pendingPush?.cancel()
        pendingPush = nil
    }

    // MARK: - State

    private func makeState() -> Attributes.ContentState {
        Attributes.ContentState(
            missionNumber: missionNumber,
            missionTotal: missionTotal,
            missionText: missionText,
            landmarkName: landmark.name,
            distanceMeters: currentDistance,
            heartRate: effectiveHeartRate,
            indicator: MissionIndicator(segmentCount: indicatorSegments,
                                        completedCount: indicatorCompleted,
                                        highlightsActive: indicatorHighlightsActive),
            updatedAt: .now,
            showsPhotoPrompt: showsPhotoPrompt
        )
    }

    /// Sensor-driven updates are throttled and skipped when nothing visible changed.
    private func push(force: Bool, reason: String) {
        guard activity != nil else { return }
        if force {
            pendingPush?.cancel()
            pendingPush = nil
            Task { await send(makeState(), reason: reason) }
            return
        }
        let next = makeState()
        guard hasVisibleChange(from: lastPushedState, to: next) else { return }
        let elapsed = lastPushDate.map { Date.now.timeIntervalSince($0) } ?? .infinity
        if elapsed >= minimumUpdateInterval {
            Task { await send(next, reason: reason) }
        } else if pendingPush == nil {
            let delay = minimumUpdateInterval - elapsed
            pendingPush = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled, let self else { return }
                self.pendingPush = nil
                await self.send(self.makeState(), reason: "遅延更新")
            }
        }
    }

    private func hasVisibleChange(from old: Attributes.ContentState?, to new: Attributes.ContentState) -> Bool {
        guard let old else { return true }
        if old.showsPhotoPrompt != new.showsPhotoPrompt { return true }
        if old.heartRate.map({ Int($0.rounded()) }) != new.heartRate.map({ Int($0.rounded()) }) { return true }
        switch (old.distanceMeters, new.distanceMeters) {
        case (nil, nil): return false
        case let (a?, b?): return abs(a - b) >= minimumDistanceDelta
        default: return true
        }
    }

    private func send(_ state: Attributes.ContentState, reason: String) async {
        guard let activity else { return }
        await activity.update(ActivityContent(state: state, staleDate: Date.now.addingTimeInterval(300)))
        lastPushedState = state
        lastPushDate = .now
        append("更新(\(reason)): \(state.distanceText) / \(state.heartRateText)\(state.showsPhotoPrompt ? " / 📷" : "")")
    }

    private func append(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 100 { log.removeLast(log.count - 100) }
    }
}

// MARK: - CLLocationManagerDelegate

extension MissionLiveActivityModel: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationStatus = status
            append("位置情報の許可: \(status.label)")
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                locationManager.allowsBackgroundLocationUpdates = status == .authorizedAlways
                if activity != nil {
                    locationManager.startUpdatingLocation()
                } else {
                    locationManager.requestLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            lastLocation = location
            push(force: false, reason: "位置更新")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in append("位置情報エラー: \(error.localizedDescription)") }
    }
}
