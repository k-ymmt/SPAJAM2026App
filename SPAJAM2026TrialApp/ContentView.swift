//
//  ContentView.swift
//  SPAJAM2026TrialApp
//
//  Created by Kazuki Yamamoto on 2026/08/17.
//

import SwiftUI

struct ContentView: View {
    @Environment(WatchHeartRateReceiver.self) private var receiver

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: isMeasuring)
                Text(heartRateText)
                    .font(.system(size: 96, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .animation(.default, value: receiver.latest?.beatsPerMinute)
    }

    private var isMeasuring: Bool {
        receiver.latest?.isMeasuring ?? false
    }

    private var heartRateText: String {
        guard let bpm = receiver.latest?.beatsPerMinute else { return "--" }
        return String(Int(bpm.rounded()))
    }

    private var statusText: String {
        guard let latest = receiver.latest else {
            return receiver.isWatchAppInstalled
                ? "Apple Watch で「計測開始」を押してください"
                : "Apple Watch にアプリをインストールしてください"
        }
        guard latest.isMeasuring else { return "計測停止中" }
        let time = latest.measuredAt.formatted(date: .omitted, time: .standard)
        return receiver.isWatchReachable ? "計測中 · 最終更新 \(time)" : "Watch 未接続 · 最終更新 \(time)"
    }
}

#Preview {
    ContentView()
        .environment(WatchHeartRateReceiver())
}
