//
//  LiveActivityTrialModel.swift
//  SPAJAM2026App
//

import ActivityKit
import Foundation
import Observation

/// Holds the editable parameters of the Live Activity trial and drives ActivityKit.
@MainActor
@Observable
final class LiveActivityTrialModel {
    typealias Attributes = TrialActivityAttributes

    enum DismissalPolicy: String, CaseIterable, Identifiable {
        case `default`, immediate, after

        var id: String { rawValue }

        var label: String {
            switch self {
            case .default: "デフォルト(最大4時間表示)"
            case .immediate: "すぐに消す"
            case .after: "指定秒後に消す"
            }
        }
    }

    // MARK: Attributes (fixed at request time)
    var title = "SPAJAM Live Activity"
    var subtitle = "お試し中"
    var accent: Attributes.Accent = .blue

    // MARK: Content state (changeable with update)
    var statusText = "準備中…"
    var emoji = "🚀"
    var progress = 0.0
    var layout: Attributes.Layout = .progress
    var timerMinutes = 3
    var showsButton = true

    // MARK: Content options
    var useStaleDate = false
    var staleAfterSeconds = 30
    var relevanceScore = 0.0

    // MARK: Request options
    var requestPushToken = false

    // MARK: Update alert
    var alertOnUpdate = false
    var alertTitle = "更新されました"
    var alertBody = "Live Activity の内容が変わりました"

    // MARK: End options
    var dismissalPolicy: DismissalPolicy = .default
    var dismissAfterSeconds = 10
    var endStatusText = "終了しました"

    // MARK: Runtime
    private(set) var activities: [Activity<Attributes>] = []
    private(set) var pushTokens: [String: String] = [:]
    private(set) var activityStates: [String: ActivityState] = [:]
    private(set) var log: [LogEntry] = []
    private(set) var areActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    private(set) var frequentPushesEnabled = ActivityAuthorizationInfo().frequentPushesEnabled

    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let message: String
    }

    private var observationTasks: [String: Task<Void, Never>] = [:]

    init() {
        refresh()
        for activity in activities {
            observe(activity)
        }
    }

    // MARK: - Derived values

    private var attributes: Attributes {
        Attributes(title: title, subtitle: subtitle, accent: accent)
    }

    private func makeState() -> Attributes.ContentState {
        Attributes.ContentState(
            statusText: statusText,
            emoji: emoji,
            progress: progress,
            timerEnd: layout == .timer ? Date.now.addingTimeInterval(TimeInterval(timerMinutes * 60)) : nil,
            layout: layout,
            showsButton: showsButton
        )
    }

    private func makeContent(state: Attributes.ContentState) -> ActivityContent<Attributes.ContentState> {
        ActivityContent(
            state: state,
            staleDate: useStaleDate ? Date.now.addingTimeInterval(TimeInterval(staleAfterSeconds)) : nil,
            relevanceScore: relevanceScore
        )
    }

    // MARK: - Actions

    func start() {
        let info = ActivityAuthorizationInfo()
        areActivitiesEnabled = info.areActivitiesEnabled
        guard info.areActivitiesEnabled else {
            append("Live Activities が無効です(設定アプリで有効にしてください)")
            return
        }
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: makeContent(state: makeState()),
                pushType: requestPushToken ? .token : nil
            )
            append("開始: id=\(activity.id.prefix(8))… pushType=\(requestPushToken ? "token" : "nil")")
            observe(activity)
            refresh()
        } catch {
            append("開始に失敗: \(error.localizedDescription)")
        }
    }

    func update(_ activity: Activity<Attributes>) {
        Task {
            let alert = alertOnUpdate
                ? AlertConfiguration(title: LocalizedStringResource(stringLiteral: alertTitle),
                                     body: LocalizedStringResource(stringLiteral: alertBody),
                                     sound: .default)
                : nil
            await activity.update(makeContent(state: makeState()), alertConfiguration: alert)
            append("更新: id=\(activity.id.prefix(8))… alert=\(alert != nil)")
        }
    }

    func updateAll() {
        activities.forEach(update)
    }

    func end(_ activity: Activity<Attributes>) {
        Task {
            var state = activity.content.state
            state.statusText = endStatusText
            let policy: ActivityUIDismissalPolicy = switch dismissalPolicy {
            case .default: .default
            case .immediate: .immediate
            case .after: .after(Date.now.addingTimeInterval(TimeInterval(dismissAfterSeconds)))
            }
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
            append("終了: id=\(activity.id.prefix(8))… policy=\(dismissalPolicy.rawValue)")
            refresh()
        }
    }

    func endAll() {
        activities.forEach(end)
    }

    /// Copies the current content state of an activity back into the editor.
    func load(from activity: Activity<Attributes>) {
        let state = activity.content.state
        statusText = state.statusText
        emoji = state.emoji
        progress = state.progress
        layout = state.layout
        showsButton = state.showsButton
        title = activity.attributes.title
        subtitle = activity.attributes.subtitle
        accent = activity.attributes.accent
        append("エディタへ読み込み: id=\(activity.id.prefix(8))…")
    }

    func refresh() {
        activities = Activity<Attributes>.activities.sorted { $0.id < $1.id }
        for activity in activities {
            activityStates[activity.id] = activity.activityState
        }
        let info = ActivityAuthorizationInfo()
        areActivitiesEnabled = info.areActivitiesEnabled
        frequentPushesEnabled = info.frequentPushesEnabled
    }

    func clearLog() {
        log.removeAll()
    }

    // MARK: - Observation

    private func observe(_ activity: Activity<Attributes>) {
        guard observationTasks[activity.id] == nil else { return }
        let id = activity.id
        observationTasks[id] = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor [weak self] in
                    for await state in activity.activityStateUpdates {
                        self?.activityStates[id] = state
                        self?.append("状態変化: id=\(id.prefix(8))… → \(String(describing: state))")
                        self?.refresh()
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await data in activity.pushTokenUpdates {
                        let token = data.map { String(format: "%02x", $0) }.joined()
                        self?.pushTokens[id] = token
                        self?.append("push token 取得: id=\(id.prefix(8))…")
                    }
                }
                group.addTask { @MainActor [weak self] in
                    for await content in activity.contentUpdates {
                        self?.append("content 更新: id=\(id.prefix(8))… progress=\(Int(content.state.progress * 100))%")
                    }
                }
            }
            self?.observationTasks[id] = nil
        }
    }

    private func append(_ message: String) {
        log.insert(LogEntry(message: message), at: 0)
        if log.count > 100 { log.removeLast(log.count - 100) }
    }
}
