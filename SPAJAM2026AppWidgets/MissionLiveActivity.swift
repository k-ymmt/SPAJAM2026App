//
//  MissionLiveActivity.swift
//  SPAJAM2026AppWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

private enum MissionPalette {
    static let accent = Color(red: 0.93, green: 0.30, blue: 0.24)
    static let accentDim = Color(red: 0.55, green: 0.22, blue: 0.20)
    static let pending = Color.white.opacity(0.18)
    static let background = Color(red: 0.13, green: 0.13, blue: 0.14)
}

/// "TABI MISSION" Live Activity.
struct MissionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MissionActivityAttributes.self) { context in
            MissionCard(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(MissionPalette.background)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MissionIcon(symbol: context.attributes.iconSymbol, size: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.missionCounterText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT MISSION")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MissionPalette.accent)
                        Text(context.state.missionText)
                            .font(.headline)
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom) {
                            MissionMetrics(state: context.state)
                            Spacer(minLength: 8)
                            if context.state.showsPhotoPrompt {
                                PhotoPromptBadge()
                            }
                        }
                        IndicatorBar(indicator: context.state.indicator)
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.iconSymbol)
                    .foregroundStyle(MissionPalette.accent)
            } compactTrailing: {
                if context.state.showsPhotoPrompt {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(MissionPalette.accent)
                } else {
                    Text(MissionDistanceFormat.distance(context.state.distanceMeters))
                        .font(.caption.monospacedDigit())
                }
            } minimal: {
                Image(systemName: context.state.showsPhotoPrompt ? "camera.fill" : context.attributes.iconSymbol)
                    .foregroundStyle(MissionPalette.accent)
            }
            .keylineTint(MissionPalette.accent)
        }
    }
}

private struct MissionCard: View {
    let attributes: MissionActivityAttributes
    let state: MissionActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MissionIcon(symbol: attributes.iconSymbol, size: 26)
                Text(attributes.brandName)
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                Spacer()
                Text(state.missionCounterText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT MISSION")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(MissionPalette.accent)
                Text(state.missionText)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }

            HStack(alignment: .bottom) {
                MissionMetrics(state: state)
                Spacer(minLength: 8)
                if state.showsPhotoPrompt {
                    PhotoPromptBadge()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            IndicatorBar(indicator: state.indicator)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// "写真を撮りませんか？" badge shown at the bottom-right when the heart rate is high.
private struct PhotoPromptBadge: View {
    var body: some View {
        Label(MissionActivityAttributes.ContentState.photoPromptText, systemImage: "camera.fill")
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MissionPalette.accent, in: Capsule())
    }
}

private struct MissionIcon: View {
    let symbol: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(MissionPalette.accent, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

private struct MissionMetrics: View {
    let state: MissionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Label(state.distanceText, systemImage: "mappin.and.ellipse")
            Label(state.heartRateText, systemImage: "heart.fill")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)
    }
}

private struct IndicatorBar: View {
    let indicator: MissionIndicator

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(indicator.segments.enumerated()), id: \.offset) { _, segment in
                Capsule()
                    .fill(color(for: segment))
                    .frame(height: 5)
            }
        }
    }

    private func color(for segment: MissionIndicator.Segment) -> Color {
        switch segment {
        case .completed: MissionPalette.accent
        case .active: MissionPalette.accentDim
        case .pending: MissionPalette.pending
        }
    }
}

#Preview("Lock screen", as: .content, using: MissionActivityAttributes(brandName: "TABI MISSION", iconSymbol: "map.fill")) {
    MissionLiveActivity()
} contentStates: {
    MissionActivityAttributes.ContentState(
        missionNumber: 2, missionTotal: 5,
        missionText: "仲見世で いちばん赤いものを撮る",
        landmarkName: "雷門", distanceMeters: 120, heartRate: 82,
        indicator: MissionIndicator(segmentCount: 5, completedCount: 1, highlightsActive: true),
        updatedAt: .now
    )
    MissionActivityAttributes.ContentState(
        missionNumber: 2, missionTotal: 5,
        missionText: "仲見世で いちばん赤いものを撮る",
        landmarkName: "雷門", distanceMeters: 120, heartRate: 131,
        indicator: MissionIndicator(segmentCount: 5, completedCount: 1, highlightsActive: true),
        updatedAt: .now, showsPhotoPrompt: true
    )
}
