//
//  ContentView.swift
//  SPAJAM2026Watch
//
//  W1: 次のミッション表示 + 心拍計測。達成イベントで W2 相当の達成演出+触覚。
//  デザイン: docs/mission-design.pen「W1 Watch 次のミッション」「W2 Watch 達成」
//

import SwiftUI

struct ContentView: View {
    @Environment(HeartRateWorkoutManager.self) private var workoutManager
    @Environment(PhoneHeartRateSender.self) private var sender
    @State private var showAchieved = false
    @State private var bannerText: String?

    var body: some View {
        ZStack {
            if let mission = sender.missionState {
                missionView(mission)
            } else {
                idleView
            }

            if let bannerText {
                eventBanner(bannerText)
            }

            if showAchieved {
                achievedOverlay
            }
        }
        .animation(.default, value: workoutManager.beatsPerMinute)
        .onChange(of: sender.achievedPulse) { _, pulse in
            guard pulse else { return }
            sender.achievedPulse = false
            withAnimation { showAchieved = true }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showAchieved = false }
            }
        }
        .onChange(of: sender.eventBanner) { _, text in
            guard let text else { return }
            sender.eventBanner = nil
            withAnimation { bannerText = text }
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { bannerText = nil }
            }
        }
        // ミッションが届いたら自動で心拍計測を開始する(スマホを見ない体験のため)
        .onChange(of: sender.missionState != nil) { _, hasMission in
            if hasMission, !workoutManager.isActive {
                Task { await workoutManager.toggle() }
            }
        }
    }

    // MARK: - W1 次のミッション

    private func missionView(_ mission: MissionState) -> some View {
        VStack(spacing: 6) {
            Text("NEXT MISSION")
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(.orange)

            Text(mission.missionTitle)
                .font(.system(size: 15, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // 進捗ドット
            HStack(spacing: 5) {
                ForEach(0..<mission.total, id: \.self) { i in
                    Circle()
                        .fill(i < mission.achievedCount ? Color.orange : Color.white.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 2)

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: workoutManager.status == .measuring)
                Text(heartRateText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("bpm")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            Text(statusText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - ミッション未受信(待機)

    private var idleView: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, isActive: workoutManager.status == .measuring)
                Text(heartRateText)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("bpm")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("iPhone で旅をはじめると\nミッションが表示されます")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await workoutManager.toggle() }
            } label: {
                Text(workoutManager.isActive ? "計測停止" : "計測開始")
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
    }

    // MARK: - イベントバナー(接近・心拍上昇・メンバー達成)

    private func eventBanner(_ text: String) -> some View {
        VStack {
            Text(text)
                .font(.system(size: 12, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.teal.opacity(0.92), in: Capsule())
            Spacer()
        }
        .padding(.top, 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - W2 達成演出

    private var achievedOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.teal, in: Circle())
            Text("達成!")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.85))
        .transition(.opacity)
    }

    private var heartRateText: String {
        guard let bpm = workoutManager.beatsPerMinute else { return "--" }
        return String(Int(bpm.rounded()))
    }

    private var statusText: String {
        switch workoutManager.status {
        case .idle: "計測停止中"
        case .starting: "計測を開始しています…"
        case .measuring: sender.isPhoneReachable ? "計測中 · iPhone 接続中" : "計測中"
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
