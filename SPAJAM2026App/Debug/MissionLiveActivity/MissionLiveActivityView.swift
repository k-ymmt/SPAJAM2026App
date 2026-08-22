//
//  MissionLiveActivityView.swift
//  SPAJAM2026App
//

import CoreLocation
import SwiftUI

/// Settings screen for the "TABI MISSION" Live Activity.
struct MissionLiveActivityView: View {
    @State private var model = MissionLiveActivityModel.shared
    @State private var manualHeartRateText = ""

    var body: some View {
        Form {
            statusSection
            missionSection
            landmarkSection
            heartRateSection
            indicatorSection
            logSection
        }
        .navigationTitle("TABI MISSION")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.requestAuthorization() }
    }

    private var statusSection: some View {
        Section {
            LabeledContent("Live Activities", value: model.areActivitiesEnabled ? "有効" : "無効")
            LabeledContent("位置情報", value: model.authorizationStatus.label)
            if model.authorizationStatus == .authorizedWhenInUse {
                Button("バックグラウンド更新のため「常に許可」を要求") { model.requestAuthorization() }
            }
            if model.isRunning {
                Button(role: .destructive) {
                    model.stop()
                } label: {
                    Label("Live Activity を終了", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                Button {
                    model.applyContent()
                } label: {
                    Label("表示内容を反映", systemImage: "paperplane.fill").frame(maxWidth: .infinity)
                }
            } else {
                Button {
                    model.start()
                } label: {
                    Label("Live Activity を開始", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.areActivitiesEnabled)
            }
        } footer: {
            Text("距離と心拍はセンサーから自動更新されます。ミッション文・カウンター・インジケータの変更は「表示内容を反映」で送信します。")
        }
    }

    private var missionSection: some View {
        Section("ミッション") {
            Picker("アイコン", selection: $model.iconSymbol) {
                ForEach(MissionLiveActivityModel.iconChoices, id: \.self) { symbol in
                    Label(symbol, systemImage: symbol).tag(symbol)
                }
            }
            .disabled(model.isRunning)
            TextField("ブランド名", text: $model.brandName).disabled(model.isRunning)
            Stepper(value: $model.missionNumber, in: 1...99) {
                LabeledContent("現在のミッション", value: "\(model.missionNumber)")
            }
            Stepper(value: $model.missionTotal, in: 1...99) {
                LabeledContent("ミッション総数", value: "\(model.missionTotal)")
            }
            TextField("NEXT MISSION", text: $model.missionText, axis: .vertical).lineLimit(1...3)
        }
    }

    private var landmarkSection: some View {
        Section {
            Picker("地点", selection: $model.landmark) {
                ForEach(MissionLandmark.presets) { landmark in
                    Text(landmark.name).tag(landmark)
                }
            }
            LabeledContent("現在地") {
                if let location = model.lastLocation {
                    Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.caption.monospacedDigit())
                } else {
                    Text("取得中…").foregroundStyle(.secondary)
                }
            }
            LabeledContent("距離", value: MissionDistanceFormat.label(landmark: model.landmark.name, meters: model.currentDistance))
        } header: {
            Text("距離の基準地点")
        } footer: {
            Text("Simulator では Features > Location > Custom Location で浅草付近(35.711, 139.796)を指定すると確認できます。")
        }
    }

    private var heartRateSection: some View {
        Section {
            LabeledContent("Apple Watch", value: model.feedStatus.watchStatus.label)
            LabeledContent("配信状態", value: model.feedStatus.isWatchStreaming ? "ストリーミング中" : "停止中")
            if let sample = model.lastHeartRate {
                LabeledContent("最新の心拍") {
                    Text("\(HeartRateFormat.bpm(sample.beatsPerMinute)) bpm (\(sample.source == .watch ? "Watch" : "HealthKit"))")
                }
            }
            HStack {
                Button("Watch で計測開始") { model.feedStatus.sendCommand(.start) }
                Spacer()
                Button("停止") { model.feedStatus.sendCommand(.stop) }
            }
            .disabled(!model.feedStatus.watchStatus.canSendCommands)
            if let error = model.feedStatus.lastCommandError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            TextField("手動の心拍 (bpm、Watch 未接続時用)", text: $manualHeartRateText)
                .keyboardType(.numberPad)
                .onChange(of: manualHeartRateText) { _, text in
                    model.manualHeartRate = Double(text)
                }
        } header: {
            Text("心拍")
        } footer: {
            Text("Watch アプリのワークアウト中は sendMessage で iPhone アプリがバックグラウンドでも起こされ、Live Activity が更新されます。フォールバックとして HealthKit のバックグラウンド配信も有効化しています。")
        }
    }

    private var indicatorSection: some View {
        Section("インジケータ") {
            Stepper(value: $model.indicatorSegments, in: 1...12) {
                LabeledContent("分割数", value: "\(model.indicatorSegments)")
            }
            Stepper(value: $model.indicatorCompleted, in: 0...model.indicatorSegments) {
                LabeledContent("完了数", value: "\(model.indicatorCompleted)")
            }
            Toggle("次のセグメントを強調", isOn: $model.indicatorHighlightsActive)
            IndicatorPreview(indicator: MissionIndicator(segmentCount: model.indicatorSegments,
                                                         completedCount: model.indicatorCompleted,
                                                         highlightsActive: model.indicatorHighlightsActive))
        }
    }

    private var logSection: some View {
        Section {
            if model.log.isEmpty {
                Text("ログはありません").foregroundStyle(.secondary)
            }
            ForEach(model.log) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.message).font(.caption)
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("ログ")
                Spacer()
                Button("クリア") { model.clearLog() }.font(.caption)
            }
        }
    }
}

private struct IndicatorPreview: View {
    let indicator: MissionIndicator

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(indicator.segments.enumerated()), id: \.offset) { _, segment in
                Capsule()
                    .fill(color(for: segment))
                    .frame(height: 6)
            }
        }
        .padding(.vertical, 4)
    }

    private func color(for segment: MissionIndicator.Segment) -> Color {
        switch segment {
        case .completed: Color(red: 0.93, green: 0.30, blue: 0.24)
        case .active: Color(red: 0.55, green: 0.22, blue: 0.20)
        case .pending: Color.gray.opacity(0.3)
        }
    }
}

#Preview {
    NavigationStack { MissionLiveActivityView() }
}
