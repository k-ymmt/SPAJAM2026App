//
//  MissionLiveActivity.swift
//  SPAJAM2026AppWidgets
//
//  デザイン: docs/mission-design.pen「03 旅行中(コントロール画面)」/
//  docs/Figma/旅中_ライブアクティビティ。
//  クリーム背景に NEXT + 番号バッジ + お題、右側は location 指定ミッションなら
//  案内マップ(App Group のスナップショット)、なければミザル。
//

import ActivityKit
import SwiftUI
import WidgetKit

private enum MissionPalette {
    /// ティール #2A7D6C
    static let accent = Color(red: 0.165, green: 0.49, blue: 0.424)
    /// 進行中セグメント(明るいティール)
    static let accentSoft = Color(red: 0.55, green: 0.76, blue: 0.70)
    /// 未達セグメント
    static let pending = Color(red: 0.78, green: 0.80, blue: 0.76)
    /// インク #2F3833
    static let ink = Color(red: 0.184, green: 0.22, blue: 0.20)
    /// サブテキスト
    static let inkSub = Color(red: 0.35, green: 0.40, blue: 0.38)
    /// カード背景(クリーム #ECEEE7)
    static let background = Color(red: 0.925, green: 0.933, blue: 0.906)
}

/// "TABI MISSION" Live Activity.
struct MissionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MissionActivityAttributes.self) { context in
            MissionCard(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(MissionPalette.background)
                .activitySystemActionForegroundColor(MissionPalette.ink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    NumberBadge(number: context.state.missionNumber, size: 26)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.missionCounterText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT")
                            .font(.caption2.weight(.bold))
                            .tracking(1)
                            .foregroundStyle(MissionPalette.accent)
                        Text(context.state.missionText)
                            .font(.headline)
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack(alignment: .bottom) {
                            MissionMetrics(state: context.state, onDark: true)
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

/// ロック画面カード(Pencil 03 コントロール画面)
private struct MissionCard: View {
    let attributes: MissionActivityAttributes
    let state: MissionActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                Text("NEXT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(MissionPalette.accent)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    NumberBadge(number: state.missionNumber, size: 24)
                    Text(state.missionText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MissionPalette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }

                MissionMetrics(state: state, onDark: false)

                if state.showsPhotoPrompt {
                    PhotoPromptBadge()
                }

                Spacer(minLength: 0)

                IndicatorBar(indicator: state.indicator)

                if let planTitle = attributes.planTitle {
                    Text(planTitle)
                        .font(.caption2)
                        .foregroundStyle(MissionPalette.inkSub)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }

            SideVisual(mapFileName: state.mapImageFileName)
        }
        .padding(14)
    }
}

/// 右側のビジュアル: location 指定ミッションは案内マップ、なければミザル
private struct SideVisual: View {
    let mapFileName: String?

    var body: some View {
        Group {
            if let mapFileName,
               let url = MapSnapshotStore.url(for: mapFileName),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image("Mizaru")
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .opacity(0.9)
            }
        }
        .frame(width: 108, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// ティールの丸バッジに白抜きのミッション番号
private struct NumberBadge: View {
    let number: Int
    let size: CGFloat

    var body: some View {
        Text("\(number)")
            .font(.system(size: size * 0.55, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(MissionPalette.accent, in: Circle())
    }
}

/// "写真を撮りませんか？" badge shown when the heart rate is high.
private struct PhotoPromptBadge: View {
    var body: some View {
        Label(MissionActivityAttributes.ContentState.photoPromptText, systemImage: "camera.fill")
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(MissionPalette.accent, in: Capsule())
    }
}

private struct MissionMetrics: View {
    let state: MissionActivityAttributes.ContentState
    var onDark: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label(state.distanceText, systemImage: "mappin.and.ellipse")
            Label(state.heartRateText, systemImage: "heart.fill")
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(onDark ? .white.opacity(0.85) : MissionPalette.inkSub)
        .labelStyle(TintedIconLabelStyle(iconColor: MissionPalette.accent))
        .lineLimit(1)
    }
}

/// アイコンだけティールにする Label スタイル
private struct TintedIconLabelStyle: LabelStyle {
    var iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(iconColor)
            configuration.title
        }
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
        case .active: MissionPalette.accentSoft
        case .pending: MissionPalette.pending
        }
    }
}

#Preview("Lock screen", as: .content, using: MissionActivityAttributes(brandName: "TABI MISSION", iconSymbol: "safari.fill", planTitle: "浅草 まったり旅")) {
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
