//
//  HeartRateView.swift
//  SPAJAM2026App
//
//  Trial screen: shows the heart rate streamed from the watch app in real time.
//

import Charts
import Combine
import SwiftUI

struct HeartRateView: View {
    @State private var monitor = HeartRateMonitor()
    @State private var now = Date.now
    @State private var pulse = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                readout
                chart
                watchControls
                statusSection
            }
            .padding()
        }
        .navigationTitle("リアルタイム心拍")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !monitor.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("履歴を消去", systemImage: "trash") {
                        withAnimation { monitor.clear() }
                    }
                }
            }
        }
        .task { await monitor.start() }
        .onDisappear { monitor.stop() }
        .onReceive(clock) { date in
            now = date
            monitor.tick(now: date)
        }
    }

    // MARK: Readout

    private var readout: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 72))
                .foregroundStyle(.red)
                .scaleEffect(pulse ? 1.18 : 1)
                .animation(beatAnimation, value: pulse)
                .onChange(of: monitor.latest?.beatsPerMinute, initial: true) { _, _ in
                    restartPulse()
                }
                .onReceive(clock) { _ in
                    if monitor.latest != nil { pulse.toggle() }
                }
                .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(monitor.latest.map { HeartRateFormat.bpm($0.beatsPerMinute) } ?? "--")
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: monitor.latest?.beatsPerMinute)
                Text("BPM")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(freshness)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var beatAnimation: Animation {
        guard let bpm = monitor.latest?.beatsPerMinute else { return .default }
        return .easeInOut(duration: min(0.45, HeartRateFormat.beatInterval(for: bpm) / 2))
    }

    private func restartPulse() {
        pulse = monitor.latest != nil
    }

    private var freshness: String {
        guard let latest = monitor.latest, let age = monitor.age(at: now) else {
            return "計測値を待っています"
        }
        let origin = latest.source == .watch ? "Watch からストリーミング" : "ヘルスケアから取得"
        if age < 2 { return "\(origin) · たった今" }
        return "\(origin) · \(Int(age)) 秒前"
    }

    // MARK: Chart

    @ViewBuilder
    private var chart: some View {
        GroupBox {
            if monitor.history.isEmpty {
                ContentUnavailableView(
                    "まだデータがありません",
                    systemImage: "waveform.path.ecg",
                    description: Text("Apple Watch で計測を開始すると、ここに直近 2 分間の推移が表示されます。")
                )
                .frame(height: 180)
            } else {
                Chart(monitor.history.samples) { sample in
                    LineMark(
                        x: .value("時刻", sample.timestamp),
                        y: .value("BPM", sample.beatsPerMinute)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.red)
                    PointMark(
                        x: .value("時刻", sample.timestamp),
                        y: .value("BPM", sample.beatsPerMinute)
                    )
                    .symbolSize(18)
                    .foregroundStyle(sample.source == .watch ? .red : .orange)
                }
                .chartXScale(domain: now.addingTimeInterval(-monitor.history.window) ... now)
                .chartYScale(domain: yDomain)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .second, count: 30)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.minute().second())
                    }
                }
                .frame(height: 180)

                HStack {
                    stat("最小", monitor.history.minimum)
                    Spacer()
                    stat("平均", monitor.history.average)
                    Spacer()
                    stat("最大", monitor.history.maximum)
                }
                .padding(.top, 4)
            }
        } label: {
            Label("直近 2 分間", systemImage: "chart.xyaxis.line")
        }
    }

    private var yDomain: ClosedRange<Double> {
        let low = (monitor.history.minimum ?? 60) - 10
        let high = (monitor.history.maximum ?? 100) + 10
        return max(30, low) ... max(high, low + 20)
    }

    private func stat(_ title: String, _ value: Double?) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value.map(HeartRateFormat.bpm) ?? "--")
                .font(.headline.monospacedDigit())
        }
    }

    // MARK: Watch controls

    private var watchControls: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        monitor.sendCommand(.start)
                    } label: {
                        Label("計測開始", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!monitor.watchStatus.canSendCommands || monitor.isWatchStreaming)

                    Button(role: .destructive) {
                        monitor.sendCommand(.stop)
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!monitor.watchStatus.canSendCommands || !monitor.isWatchStreaming)
                }

                if let error = monitor.lastCommandError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("Watch 側のアプリでも開始・停止できます。計測中は Watch でワークアウトセッションが動作します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Apple Watch", systemImage: "applewatch")
        }
    }

    // MARK: Status

    private var statusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                statusRow(
                    "Watch",
                    monitor.watchStatus.label,
                    ok: monitor.watchStatus.isReachable
                )
                statusRow(
                    "ストリーミング",
                    monitor.isWatchStreaming ? "計測中" : "停止中",
                    ok: monitor.isWatchStreaming
                )
                statusRow(
                    "ヘルスケア",
                    healthLabel,
                    ok: monitor.healthAuthorization == .authorized
                )
            }
        } label: {
            Label("接続状態", systemImage: "antenna.radiowaves.left.and.right")
        }
    }

    private var healthLabel: String {
        switch monitor.healthAuthorization {
        case .unavailable: "この端末では利用できません"
        case .notDetermined: "許可を確認中"
        case .denied: "アクセスが許可されていません"
        case .authorized: "心拍データを監視中(フォールバック)"
        }
    }

    private func statusRow(_ title: String, _ detail: String, ok: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Circle()
                .fill(ok ? .green : .secondary)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        HeartRateView()
    }
}
