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
