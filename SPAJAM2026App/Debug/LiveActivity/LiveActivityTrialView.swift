//
//  LiveActivityTrialView.swift
//  SPAJAM2026App
//

import ActivityKit
import SwiftUI

/// Screen to tweak every knob of a Live Activity and run it for real.
struct LiveActivityTrialView: View {
    @State private var model = LiveActivityTrialModel()

    var body: some View {
        Form {
            statusSection
            attributesSection
            contentStateSection
            contentOptionsSection
            alertSection
            endSection
            activitiesSection
            logSection
        }
        .navigationTitle("Live Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("更新", systemImage: "arrow.clockwise") { model.refresh() }
            }
        }
        .onAppear { model.refresh() }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            LabeledContent("Live Activities", value: model.areActivitiesEnabled ? "有効" : "無効")
            LabeledContent("Frequent pushes", value: model.frequentPushesEnabled ? "有効" : "無効")
            Button {
                model.start()
            } label: {
                Label("Live Activity を開始", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.areActivitiesEnabled)
        } footer: {
            Text("開始後はホーム画面に戻るか画面をロックすると、Dynamic Island / ロック画面に表示されます。")
        }
    }

    private var attributesSection: some View {
        Section {
            TextField("タイトル", text: $model.title)
            TextField("サブタイトル", text: $model.subtitle)
            Picker("アクセントカラー", selection: $model.accent) {
                ForEach(TrialActivityAttributes.Accent.allCases) { accent in
                    Label {
                        Text(accent.rawValue)
                    } icon: {
                        Image(systemName: "circle.fill").foregroundStyle(accent.color)
                    }
                    .tag(accent)
                }
            }
            Toggle("push token を要求 (pushType: .token)", isOn: $model.requestPushToken)
        } header: {
            Text("Attributes(開始時に固定)")
        }
    }

    private var contentStateSection: some View {
        Section {
            Picker("レイアウト", selection: $model.layout) {
                ForEach(TrialActivityAttributes.Layout.allCases) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            TextField("ステータス文言", text: $model.statusText)
            TextField("絵文字", text: $model.emoji)
            if model.layout == .progress {
                VStack(alignment: .leading) {
                    Text("進捗: \(Int(model.progress * 100))%")
                    Slider(value: $model.progress, in: 0...1, step: 0.05)
                }
            }
            if model.layout == .timer {
                Stepper("カウントダウン: \(model.timerMinutes) 分", value: $model.timerMinutes, in: 1...60)
            }
            Toggle("「進める」ボタンを表示 (LiveActivityIntent)", isOn: $model.showsButton)
        } header: {
            Text("ContentState(update で変更可)")
        }
    }

    private var contentOptionsSection: some View {
        Section {
            Toggle("staleDate を設定", isOn: $model.useStaleDate)
            if model.useStaleDate {
                Stepper("\(model.staleAfterSeconds) 秒後に stale", value: $model.staleAfterSeconds, in: 5...600, step: 5)
            }
            VStack(alignment: .leading) {
                Text("relevanceScore: \(model.relevanceScore, format: .number.precision(.fractionLength(1)))")
                Slider(value: $model.relevanceScore, in: 0...100, step: 1)
            }
        } header: {
            Text("ActivityContent オプション")
        } footer: {
            Text("staleDate を過ぎると isStale が true になり、ビューに警告が出ます。relevanceScore は複数の Activity の表示順に影響します。")
        }
    }

    private var alertSection: some View {
        Section {
            Toggle("更新時にアラートを出す", isOn: $model.alertOnUpdate)
            if model.alertOnUpdate {
                TextField("アラートタイトル", text: $model.alertTitle)
                TextField("アラート本文", text: $model.alertBody)
            }
        } header: {
            Text("AlertConfiguration(update 時)")
        } footer: {
            Text("アラート付き更新は Dynamic Island を展開表示し、Apple Watch にも通知されます。")
        }
    }

    private var endSection: some View {
        Section {
            Picker("dismissalPolicy", selection: $model.dismissalPolicy) {
                ForEach(LiveActivityTrialModel.DismissalPolicy.allCases) { policy in
                    Text(policy.label).tag(policy)
                }
            }
            if model.dismissalPolicy == .after {
                Stepper("\(model.dismissAfterSeconds) 秒後", value: $model.dismissAfterSeconds, in: 5...600, step: 5)
            }
            TextField("終了時のステータス文言", text: $model.endStatusText)
        } header: {
            Text("終了オプション")
        }
    }

    private var activitiesSection: some View {
        Section {
            if model.activities.isEmpty {
                Text("実行中の Live Activity はありません")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.activities, id: \.id) { activity in
                ActivityRow(activity: activity, model: model)
            }
            if model.activities.count > 1 {
                Button("すべて更新", systemImage: "arrow.triangle.2.circlepath") { model.updateAll() }
                Button("すべて終了", systemImage: "stop.fill", role: .destructive) { model.endAll() }
            }
        } header: {
            Text("実行中の Activity (\(model.activities.count))")
        }
    }

    private var logSection: some View {
        Section {
            if model.log.isEmpty {
                Text("ログなし").foregroundStyle(.secondary)
            }
            ForEach(model.log) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.message)
                        .font(.caption)
                }
            }
        } header: {
            HStack {
                Text("ログ")
                Spacer()
                Button("クリア") { model.clearLog() }
                    .font(.caption)
                    .disabled(model.log.isEmpty)
            }
        }
    }
}

// MARK: - Row

private struct ActivityRow: View {
    let activity: Activity<TrialActivityAttributes>
    let model: LiveActivityTrialModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(activity.content.state.emoji)
                Text(activity.attributes.title)
                    .font(.headline)
                Spacer()
                Text(stateLabel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Text("id: \(activity.id)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("\(activity.content.state.statusText) / \(Int(activity.content.state.progress * 100))% / \(activity.content.state.layout.label)")
                .font(.caption)
            if let token = model.pushTokens[activity.id] {
                Text("push token: \(token)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }
            HStack {
                Button("更新", systemImage: "arrow.triangle.2.circlepath") { model.update(activity) }
                Button("読込", systemImage: "square.and.arrow.down") { model.load(from: activity) }
                Spacer()
                Button("終了", systemImage: "stop.fill", role: .destructive) { model.end(activity) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
    }

    private var stateLabel: String {
        switch model.activityStates[activity.id] ?? activity.activityState {
        case .active: "active"
        case .ended: "ended"
        case .dismissed: "dismissed"
        case .stale: "stale"
        case .pending: "pending"
        @unknown default: "unknown"
        }
    }
}

#Preview {
    NavigationStack {
        LiveActivityTrialView()
    }
}
