//
//  ContentView.swift
//  SPAJAM2026WatchApp Watch App
//
//  Shows the live heart rate and controls the workout session that feeds the
//  phone app.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = HeartRateWorkoutManager()

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: manager.isRunning)
                Text(manager.beatsPerMinute.map(HeartRateFormat.bpm) ?? "--")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("BPM")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(manager.isPhoneReachable ? "iPhone と接続中" : "iPhone 未接続")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            Button {
                if manager.isRunning {
                    manager.stop()
                } else {
                    Task { await manager.start() }
                }
            } label: {
                Label(
                    manager.isRunning ? "停止" : "計測開始",
                    systemImage: manager.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .tint(manager.isRunning ? .red : .green)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
