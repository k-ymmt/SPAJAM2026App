//
//  ContentView.swift
//  SPAJAM2026Watch
//
//  Created by Kazuki Yamamoto on 2026/08/17.
//

import SwiftUI

struct ContentView: View {
    @Environment(HeartRateWorkoutManager.self) private var workoutManager
    @Environment(PhoneHeartRateSender.self) private var sender

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: workoutManager.status == .measuring)
                Text(heartRateText)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                Task { await workoutManager.toggle() }
            } label: {
                Text(workoutManager.isActive ? "停止" : "計測開始")
                    .frame(maxWidth: .infinity)
            }
            .tint(workoutManager.isActive ? .red : .green)
            .disabled(workoutManager.status == .starting || workoutManager.status == .stopping)

            if let errorMessage = workoutManager.errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .animation(.default, value: workoutManager.beatsPerMinute)
    }

    private var heartRateText: String {
        guard let bpm = workoutManager.beatsPerMinute else { return "--" }
        return String(Int(bpm.rounded()))
    }

    private var statusText: String {
        switch workoutManager.status {
        case .idle: "停止中"
        case .starting: "開始しています…"
        case .measuring: sender.isPhoneReachable ? "計測中 · iPhone 接続中" : "計測中 · iPhone 未接続"
        case .stopping: "停止しています…"
        }
    }
}

#Preview {
    let sender = PhoneHeartRateSender()
    ContentView()
        .environment(HeartRateWorkoutManager(sender: sender))
        .environment(sender)
}
