//
//  ScreenTimeDeviceActivityView.swift
//  SPAJAM2026App
//

import DeviceActivity
import FamilyControls
import SwiftUI

/// Trial of `DeviceActivityCenter`: build a schedule + threshold event and
/// start / stop monitoring.
struct ScreenTimeDeviceActivityView: View {
    @Bindable var model: ScreenTimeTrialModel
    @State private var activityName = "trial"
    @State private var builder = ScreenTimeScheduleBuilder()
    @State private var addsEvent = true
    @State private var eventName = "threshold"
    @State private var thresholdMinutes = 15
    @State private var includesPastActivity = false

    var body: some View {
        Form {
            Section {
                TextField("DeviceActivityName", text: $activityName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("アクティビティ名")
            }

            Section {
                Stepper("開始 \(ScreenTimeFormat.time(hour: builder.startHour, minute: builder.startMinute))",
                        onIncrement: { builder.shiftStart(by: 15) },
                        onDecrement: { builder.shiftStart(by: -15) })
                Stepper("終了 \(ScreenTimeFormat.time(hour: builder.endHour, minute: builder.endMinute))",
                        onIncrement: { builder.shiftEnd(by: 15) },
                        onDecrement: { builder.shiftEnd(by: -15) })
                Toggle("repeats(毎日繰り返す)", isOn: $builder.repeats)
                Stepper("warningTime: \(builder.warningMinutes) 分前", value: $builder.warningMinutes, in: 0...60, step: 5)
                Button("今から 30 分のスケジュールにする", systemImage: "clock") {
                    builder = .fromNow(minutes: 30)
                }
                LabeledContent("区間の長さ", value: "\(builder.durationMinutes) 分")
                if !builder.isValid {
                    Label("区間は 15 分以上にしてください", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            } header: {
                Text("DeviceActivitySchedule")
            } footer: {
                Text("intervalStart / intervalEnd は DateComponents(時・分)で指定します。warningTime を付けると区間終了前に intervalWillEndWarning が呼ばれます。")
            }

            Section {
                Toggle("しきい値イベントを追加", isOn: $addsEvent)
                if addsEvent {
                    TextField("DeviceActivityEvent.Name", text: $eventName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Stepper("threshold: \(thresholdMinutes) 分", value: $thresholdMinutes, in: 1...240)
                    Toggle("includesPastActivity", isOn: $includesPastActivity)
                    LabeledContent("対象", value: ScreenTimeFormat.summary(
                        applications: model.selection.applicationTokens.count,
                        categories: model.selection.categoryTokens.count,
                        webDomains: model.selection.webDomainTokens.count
                    ))
                }
            } header: {
                Text("DeviceActivityEvent")
            } footer: {
                Text("選択中のアプリ・カテゴリ・Web ドメインの合計利用時間がしきい値に達すると eventDidReachThreshold が呼ばれます。")
            }

            Section {
                Button {
                    start()
                } label: {
                    Label("startMonitoring", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isAuthorized || !builder.isValid || activityName.isEmpty)
            } footer: {
                Text("コールバック(intervalDidStart / eventDidReachThreshold など)を受け取るには DeviceActivityMonitor 拡張が必要です。この画面では監視の登録・照会・停止を試せます。")
            }

            Section {
                if model.monitoredActivities.isEmpty {
                    Text("監視中のアクティビティはありません").foregroundStyle(.secondary)
                }
                ForEach(model.monitoredActivities, id: \.rawValue) { name in
                    MonitoredActivityRow(name: name, model: model)
                }
                Button("再読込", systemImage: "arrow.clockwise") { model.refreshActivities() }
                if !model.monitoredActivities.isEmpty {
                    Button("すべて停止", systemImage: "stop.fill", role: .destructive) { model.stopAllMonitoring() }
                }
            } header: {
                Text("監視中 (\(model.monitoredActivities.count))")
            }

            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("利用状況モニタリング")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.refreshActivities() }
    }

    private func start() {
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if addsEvent, !eventName.isEmpty {
            events[DeviceActivityEvent.Name(eventName)] = DeviceActivityEvent(
                applications: model.selection.applicationTokens,
                categories: model.selection.categoryTokens,
                webDomains: model.selection.webDomainTokens,
                threshold: DateComponents(minute: thresholdMinutes),
                includesPastActivity: includesPastActivity
            )
        }
        model.startMonitoring(name: activityName, schedule: builder.makeSchedule(), events: events)
    }
}

private struct MonitoredActivityRow: View {
    let name: DeviceActivityName
    let model: ScreenTimeTrialModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name.rawValue).font(.headline)
                Spacer()
                Button("停止", systemImage: "stop.fill", role: .destructive) {
                    model.stopMonitoring([name])
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if let schedule = model.center.schedule(for: name) {
                Text("schedule: \(time(schedule.intervalStart)) – \(time(schedule.intervalEnd)) repeats=\(schedule.repeats)")
                    .font(.caption)
                if let next = schedule.nextInterval {
                    Text("nextInterval: \(next.start, format: .dateTime.month().day().hour().minute()) – \(next.end, format: .dateTime.hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            let events = model.center.events(for: name)
            ForEach(Array(events.keys).sorted { $0.rawValue < $1.rawValue }, id: \.rawValue) { key in
                Text("event \(key.rawValue): threshold=\(events[key]?.threshold.minute ?? 0) 分")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func time(_ components: DateComponents) -> String {
        ScreenTimeFormat.time(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }
}
