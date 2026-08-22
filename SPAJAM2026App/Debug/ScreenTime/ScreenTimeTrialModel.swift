//
//  ScreenTimeTrialModel.swift
//  SPAJAM2026App
//

import Combine
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

/// Shared state for the Screen Time API trials: authorization, the picked
/// activity selection, the settings store and an event log.
@MainActor
@Observable
final class ScreenTimeTrialModel {

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    // MARK: Authorization
    private(set) var authorizationStatus: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    var member: FamilyControlsMember = .individual
    private(set) var isRequesting = false

    // MARK: Activity selection
    var selection: FamilyActivitySelection {
        didSet { ScreenTimeSelectionStore.save(selection) }
    }
    var includeEntireCategory = false

    // MARK: Managed settings
    var storeName = ""
    private(set) var store = ManagedSettingsStore()

    // MARK: Device activity
    let center = DeviceActivityCenter()
    private(set) var monitoredActivities: [DeviceActivityName] = []

    private(set) var log: [LogEntry] = []
    private var cancellables = Set<AnyCancellable>()

    init() {
        selection = ScreenTimeSelectionStore.load() ?? FamilyActivitySelection()
        includeEntireCategory = selection.includeEntireCategory
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self, status != authorizationStatus else { return }
                authorizationStatus = status
                append("認可状態が変化: \(ScreenTimeFormat.label(for: status))")
            }
            .store(in: &cancellables)
        refreshActivities()
    }

    var isAuthorized: Bool { authorizationStatus == .approved }

    // MARK: - Authorization

    func requestAuthorization() {
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            defer { isRequesting = false }
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: member)
                authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                append("requestAuthorization(for: .\(member)) 成功 → \(ScreenTimeFormat.label(for: authorizationStatus))")
            } catch {
                append("requestAuthorization 失敗: \(error.localizedDescription)")
            }
        }
    }

    func revokeAuthorization() {
        AuthorizationCenter.shared.revokeAuthorization { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    self?.authorizationStatus = AuthorizationCenter.shared.authorizationStatus
                    self?.append("revokeAuthorization 成功")
                case .failure(let error):
                    self?.append("revokeAuthorization 失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    func refreshAuthorization() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: - Selection

    func resetSelection() {
        selection = FamilyActivitySelection(includeEntireCategory: includeEntireCategory)
        append("選択をリセット(includeEntireCategory=\(includeEntireCategory))")
    }

    func applyIncludeEntireCategory() {
        var copy = FamilyActivitySelection(includeEntireCategory: includeEntireCategory)
        copy.applicationTokens = selection.applicationTokens
        copy.categoryTokens = selection.categoryTokens
        copy.webDomainTokens = selection.webDomainTokens
        selection = copy
        append("includeEntireCategory=\(includeEntireCategory) で選択を作り直し")
    }

    // MARK: - Managed settings

    func switchStore() {
        let name = storeName.trimmingCharacters(in: .whitespaces)
        store = name.isEmpty ? ManagedSettingsStore() : ManagedSettingsStore(named: .init(name))
        append("ManagedSettingsStore を切替: \(name.isEmpty ? "default" : name)")
    }

    func clearAllSettings() {
        store.clearAllSettings()
        append("clearAllSettings()")
    }

    // MARK: - Device activity

    func startMonitoring(name: String, schedule: DeviceActivitySchedule, events: [DeviceActivityEvent.Name: DeviceActivityEvent]) {
        do {
            try center.startMonitoring(DeviceActivityName(name), during: schedule, events: events)
            append("startMonitoring(\(name)) events=\(events.count)")
        } catch {
            append("startMonitoring 失敗: \(error.localizedDescription)")
        }
        refreshActivities()
    }

    func stopMonitoring(_ names: [DeviceActivityName]) {
        center.stopMonitoring(names)
        append("stopMonitoring(\(names.map(\.rawValue).joined(separator: ", ")))")
        refreshActivities()
    }

    func stopAllMonitoring() {
        center.stopMonitoring()
        append("stopMonitoring() — すべて停止")
        refreshActivities()
    }

    func refreshActivities() {
        monitoredActivities = center.activities.sorted { $0.rawValue < $1.rawValue }
    }

    // MARK: - Log

    func append(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 200 { log.removeLast(log.count - 200) }
    }

    func clearLog() {
        log.removeAll()
    }
}

// MARK: - Persistence

/// Persists the picked FamilyActivitySelection so it survives relaunches.
enum ScreenTimeSelectionStore {
    static let key = "screenTime.selection"
    nonisolated(unsafe) static var defaults = UserDefaults.standard

    static func save(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: key)
        }
    }

    static func load() -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}

// MARK: - Formatting helpers (pure, unit-testable)

enum ScreenTimeFormat {
    static func label(for status: AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: "未決定 (notDetermined)"
        case .denied: "拒否 (denied)"
        case .approved: "承認済み (approved)"
        @unknown default: "不明"
        }
    }

    static func label(for member: FamilyControlsMember) -> String {
        switch member {
        case .individual: "individual(本人)"
        case .child: "child(子ども)"
        @unknown default: "不明"
        }
    }

    /// Builds the "N apps / N categories / N domains" summary for a selection.
    static func summary(applications: Int, categories: Int, webDomains: Int) -> String {
        "アプリ \(applications) / カテゴリ \(categories) / Web \(webDomains)"
    }

    static func time(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

/// Builds DeviceActivity schedules from simple hour/minute inputs.
struct ScreenTimeScheduleBuilder: Equatable {
    var startHour = 0
    var startMinute = 0
    var endHour = 23
    var endMinute = 59
    var repeats = true
    var warningMinutes = 0

    var startComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }

    var endComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMinute)
    }

    var warningComponents: DateComponents? {
        warningMinutes > 0 ? DateComponents(minute: warningMinutes) : nil
    }

    /// Interval length in minutes; a schedule must cover at least 15 minutes.
    var durationMinutes: Int {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        return end >= start ? end - start : end + 24 * 60 - start
    }

    var isValid: Bool { durationMinutes >= 15 }

    /// Moves the start time by `delta` minutes, wrapping around midnight.
    mutating func shiftStart(by delta: Int) {
        (startHour, startMinute) = Self.shifted(hour: startHour, minute: startMinute, by: delta)
    }

    /// Moves the end time by `delta` minutes, wrapping around midnight.
    mutating func shiftEnd(by delta: Int) {
        (endHour, endMinute) = Self.shifted(hour: endHour, minute: endMinute, by: delta)
    }

    static func shifted(hour: Int, minute: Int, by delta: Int) -> (hour: Int, minute: Int) {
        var total = (hour * 60 + minute + delta) % (24 * 60)
        if total < 0 { total += 24 * 60 }
        return (total / 60, total % 60)
    }

    func makeSchedule() -> DeviceActivitySchedule {
        DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: repeats,
            warningTime: warningComponents
        )
    }

    /// Convenience: a schedule starting now and lasting `minutes`.
    static func fromNow(minutes: Int, calendar: Calendar = .current, now: Date = .now) -> ScreenTimeScheduleBuilder {
        let end = now.addingTimeInterval(TimeInterval(minutes * 60))
        let s = calendar.dateComponents([.hour, .minute], from: now)
        let e = calendar.dateComponents([.hour, .minute], from: end)
        return ScreenTimeScheduleBuilder(
            startHour: s.hour ?? 0, startMinute: s.minute ?? 0,
            endHour: e.hour ?? 0, endMinute: e.minute ?? 0,
            repeats: false, warningMinutes: 0
        )
    }
}
