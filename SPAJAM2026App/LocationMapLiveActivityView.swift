//
//  LocationMapLiveActivityView.swift
//  SPAJAM2026App
//

import CoreLocation
import SwiftUI

/// Screen that starts a Live Activity showing a map snapshot of the current location,
/// refreshed in the background as the device moves.
struct LocationMapLiveActivityView: View {
    @State private var model = LocationMapLiveActivityModel()

    var body: some View {
        Form {
            statusSection
            previewSection
            settingsSection
            logSection
        }
        .navigationTitle("地図 Live Activity")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { model.requestAuthorization() }
    }

    private var statusSection: some View {
        Section {
            LabeledContent("Live Activities", value: model.areActivitiesEnabled ? "有効" : "無効")
            LabeledContent("位置情報", value: model.authorizationStatus.label)
            if model.authorizationStatus == .authorizedWhenInUse {
                Button("バックグラウンド更新のため「常に許可」を要求") {
                    model.requestAuthorization()
                }
            }
            if let location = model.lastLocation {
                LabeledContent("現在地") {
                    Text(String(format: "%.5f, %.5f", location.coordinate.latitude, location.coordinate.longitude))
                        .font(.caption.monospacedDigit())
                }
            }
            if model.isTracking {
                Button(role: .destructive) {
                    model.stop()
                } label: {
                    Label("追跡を終了", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    model.forceUpdate()
                } label: {
                    Label("今すぐ地図を更新", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .disabled(model.isRenderingSnapshot)
            } else {
                Button {
                    model.start()
                } label: {
                    Label("追跡を開始", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.areActivitiesEnabled)
            }
        } footer: {
            Text("開始後、端末が移動すると MKMapSnapshotter で地図画像を生成し、App Group 経由で Live Activity に表示します。「常に許可」にするとアプリがバックグラウンドでも更新が続きます。Simulator では Features > Location > Freeway Drive で移動を再現できます。")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let image = model.lastSnapshot {
            Section("最新のスナップショット") {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                    .overlay(alignment: .bottomTrailing) {
                        if model.isRenderingSnapshot {
                            ProgressView().padding(8)
                        }
                    }
            }
        }
    }

    private var settingsSection: some View {
        Section {
            Stepper(value: $model.minimumUpdateInterval, in: 5...300, step: 5) {
                LabeledContent("最小更新間隔", value: "\(Int(model.minimumUpdateInterval)) 秒")
            }
            Stepper(value: $model.minimumDistance, in: 0...500, step: 10) {
                LabeledContent("最小移動距離", value: "\(Int(model.minimumDistance)) m")
            }
            Stepper(value: $model.regionSpan, in: 200...5000, step: 100) {
                LabeledContent("表示範囲", value: "\(Int(model.regionSpan)) m")
            }
            TextField("タイトル", text: $model.title)
                .disabled(model.isTracking)
        } header: {
            Text("更新条件")
        } footer: {
            Text("間隔と距離の両方を満たしたときに地図を再生成します。スナップショット生成はネットワークを使うため、頻度は控えめにしてください。")
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

#Preview {
    NavigationStack { LocationMapLiveActivityView() }
}
