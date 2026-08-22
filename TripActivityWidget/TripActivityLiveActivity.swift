//
//  TripActivityLiveActivity.swift
//  TripActivityWidget
//
//  ロック画面 / Dynamic Island に「次のミッションだけ」を表示する Live Activity。
//  デザインは docs/mission-design.pen「03 旅行中(コントロール画面)」準拠。
//

import ActivityKit
import SwiftUI
import WidgetKit

struct TripActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // ロック画面
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("TABI MISSION", systemImage: "safari.fill")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("ミッション \(context.state.missionOrder)/\(context.state.missionTotal)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(context.state.missionTitle)
                    .font(.title3.bold())
                HStack(spacing: 14) {
                    if let distance = context.state.distanceText {
                        Label(distance, systemImage: "mappin.and.ellipse")
                    }
                    if let bpm = context.state.bpm {
                        Label("\(bpm) bpm", systemImage: "heart.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                ProgressView(value: Double(context.state.missionOrder - 1), total: Double(context.state.missionTotal))
                    .tint(.orange)
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("ミッション \(context.state.missionOrder)/\(context.state.missionTotal)")
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let bpm = context.state.bpm {
                        Label("\(bpm)", systemImage: "heart.fill")
                            .font(.caption)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.missionTitle)
                        .font(.headline)
                }
            } compactLeading: {
                Image(systemName: "safari.fill")
            } compactTrailing: {
                Text("\(context.state.missionOrder)/\(context.state.missionTotal)")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "safari.fill")
            }
        }
    }
}
