//
//  LocationMapLiveActivity.swift
//  SPAJAM2026AppWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Live Activity that shows a map snapshot rendered by the app and shared via the App Group.
struct LocationMapLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LocationMapActivityAttributes.self) { context in
            LockScreenMapView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.3))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.updatedAt, style: .relative)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SnapshotImage(fileName: context.state.imageFileName)
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } compactLeading: {
                Image(systemName: "location.fill").foregroundStyle(.blue)
            } compactTrailing: {
                Text("#\(context.state.updateCount)")
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "location.fill").foregroundStyle(.blue)
            }
            .keylineTint(.blue)
        }
    }
}

private struct LockScreenMapView: View {
    let context: ActivityViewContext<LocationMapActivityAttributes>

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SnapshotImage(fileName: context.state.imageFileName)
            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.title)
                        .font(.headline)
                    Text(String(format: "%.4f, %.4f  ±%.0fm",
                                context.state.latitude, context.state.longitude, context.state.accuracy))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.updatedAt, style: .relative)
                        .font(.caption.monospacedDigit())
                    Text("更新 #\(context.state.updateCount)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                if context.isStale {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            .foregroundStyle(.white)
            .padding(12)
        }
        .frame(height: 150)
    }
}

/// Loads the snapshot from the App Group container. Falls back to a placeholder until the
/// app has rendered the first image.
private struct SnapshotImage: View {
    let fileName: String?

    var body: some View {
        if let fileName,
           let url = MapSnapshotStore.url(for: fileName),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.gray.opacity(0.3)
                VStack(spacing: 4) {
                    Image(systemName: "map")
                        .font(.title)
                    Text("位置情報を取得中…")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}
