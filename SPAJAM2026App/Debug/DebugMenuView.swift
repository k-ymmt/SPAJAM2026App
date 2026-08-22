//
//  DebugMenuView.swift
//  SPAJAM2026App
//
//  端末を振ると表示されるデバッグ用シート。フレームワークのお試し画面への導線をまとめる。
//

import SwiftUI

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    /// いま進行中の旅(なければ nil)。デモ・検証セクションで使う
    var activeSession: TripSession?

    var body: some View {
        NavigationStack {
            List {
                Section("デモ・検証") {
                    if let session = activeSession {
                        @Bindable var session = session
                        Toggle(isOn: $session.useMockJudge) {
                            TrialRow(
                                title: "Mock 判定",
                                subtitle: "AI 画像判定をローカルの Mock に切り替えます(電波なしデモ用)。",
                                systemImage: "wand.and.stars"
                            )
                        }
                        Button {
                            session.noteMemberAchieved(
                                memberName: "ひろせ",
                                missionTitle: session.currentMission?.title ?? "ミッション"
                            )
                        } label: {
                            TrialRow(
                                title: "メンバー達成をシミュレート",
                                subtitle: "他メンバーの達成通知と Watch 触覚を発火させます(旅行中のみ)。",
                                systemImage: "person.2.wave.2"
                            )
                        }
                    }
                    Button {
                        let demo = TripSession(plan: .bundledDemoPlan())
                        demo.persist()
                        NotificationCenter.default.post(name: TripSessionStore.didChange, object: nil)
                        dismiss()
                    } label: {
                        TrialRow(
                            title: "デモプラン(浅草)で開始",
                            subtitle: "保存セッションを浅草のデモプランで置き換えて、プラン画面から始めます。",
                            systemImage: "figure.walk.motion"
                        )
                    }
                }
                Section("アプリ状態") {
                    NavigationLink {
                        SavedSessionEditorView()
                    } label: {
                        TrialRow(
                            title: "保存セッション",
                            subtitle: "キル後に復元される旅の状態を表示・編集・クリアします。保存すると即座に反映されます。",
                            systemImage: "externaldrive.badge.timemachine"
                        )
                    }
                }
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
                        MissionLiveActivityView()
                    } label: {
                        TrialRow(
                            title: "TABI MISSION Live Activity",
                            subtitle: "ミッション・地点からの距離・Apple Watch の心拍を Live Activity に表示します。",
                            systemImage: "mappin.and.ellipse"
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
            .navigationTitle("デバッグメニュー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
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
    DebugMenuView()
}
