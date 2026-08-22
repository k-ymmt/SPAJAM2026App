//
//  TrialLiveActivity.swift
//  SPAJAM2026AppWidgets
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct TrialLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrialActivityAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(context.attributes.accent.color.opacity(0.2))
                .activitySystemActionForegroundColor(context.attributes.accent.color)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.emoji)
                        .font(.largeTitle)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingValue(context: context)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(context.attributes.accent.color)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    BottomContent(context: context)
                }
            } compactLeading: {
                Text(context.state.emoji)
            } compactTrailing: {
                TrailingValue(context: context)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(context.attributes.accent.color)
                    .frame(maxWidth: 48)
            } minimal: {
                Text(context.state.emoji)
            }
            .keylineTint(context.attributes.accent.color)
        }
    }
}

// MARK: - Lock screen / banner

private struct LockScreenView: View {
    let context: ActivityViewContext<TrialActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(context.state.emoji)
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                    if !context.attributes.subtitle.isEmpty {
                        Text(context.attributes.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                TrailingValue(context: context)
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(context.attributes.accent.color)
            }
            Text(context.state.statusText)
                .font(.subheadline)
            BottomContent(context: context)
            if context.isStale {
                Label("古い情報です (stale)", systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Shared pieces

/// Right-aligned number: percentage, countdown or nothing depending on layout.
private struct TrailingValue: View {
    let context: ActivityViewContext<TrialActivityAttributes>

    var body: some View {
        switch context.state.layout {
        case .progress:
            Text(context.state.progress, format: .percent.precision(.fractionLength(0)))
        case .timer:
            if let end = context.state.timerEnd {
                Text(timerInterval: Date.now...max(end, Date.now), countsDown: true)
                    .multilineTextAlignment(.trailing)
            } else {
                Text("--:--")
            }
        case .plain:
            EmptyView()
        }
    }
}

/// Progress bar / timer bar / interactive button row.
private struct BottomContent: View {
    let context: ActivityViewContext<TrialActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            switch context.state.layout {
            case .progress:
                ProgressView(value: context.state.progress)
                    .tint(context.attributes.accent.color)
            case .timer:
                if let end = context.state.timerEnd {
                    ProgressView(timerInterval: Date.now...max(end, Date.now), countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .tint(context.attributes.accent.color)
                }
            case .plain:
                EmptyView()
            }
            if context.state.showsButton {
                Button(intent: AdvanceTrialActivityIntent(activityID: context.activityID)) {
                    Label("進める (+10%)", systemImage: "forward.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(context.attributes.accent.color)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}
