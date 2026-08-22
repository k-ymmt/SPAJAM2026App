//
//  ContentView.swift
//  SPAJAM2026App
//
//  Created by Kazuki Yamamoto on 2026/08/21.
//

import SwiftUI

/// Entry screen: a menu of the framework trials in this app.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("フレームワークお試し") {
                    NavigationLink {
                        JournalingSuggestionsView()
                    } label: {
                        TrialRow(
                            title: "Journaling Suggestions",
                            subtitle: "システムのピッカーで候補を選び、内容を一覧表示します。",
                            systemImage: "sparkles"
                        )
                    }
                    NavigationLink {
                        LiveActivityTrialView()
                    } label: {
                        TrialRow(
                            title: "Live Activities",
                            subtitle: "属性・状態・アラート・終了方法を変えて Live Activity を実行します。",
                            systemImage: "platter.filled.top.iphone"
                        )
                    }
                    NavigationLink {
                        LocationMapLiveActivityView()
                    } label: {
                        TrialRow(
                            title: "地図 Live Activity",
                            subtitle: "現在地の地図画像をバックグラウンドで生成し、Live Activity に表示し続けます。",
                            systemImage: "map.fill"
                        )
                    }
                    NavigationLink {
                        ScreenTimeTrialView()
                    } label: {
                        TrialRow(
                            title: "Screen Time API",
                            subtitle: "認可・アプリ選択・シールド・各種制限・利用状況モニタリングを試します。",
                            systemImage: "hourglass"
                        )
                    }
                    NavigationLink {
                        HeartRateView()
                    } label: {
                        TrialRow(
                            title: "リアルタイム心拍",
                            subtitle: "Apple Watch で計測した心拍をリアルタイムに表示します。",
                            systemImage: "heart.fill"
                        )
                    }
                }
            }
            .navigationTitle("SPAJAM2026")
        }
    }
}

private struct TrialRow: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
