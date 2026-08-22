//
//  ScreenTimeTrialView.swift
//  SPAJAM2026App
//

import FamilyControls
import SwiftUI

/// Sub-menu listing everything the Screen Time API (FamilyControls /
/// ManagedSettings / DeviceActivity) lets us try.
struct ScreenTimeTrialView: View {
    @State private var model = ScreenTimeTrialModel()

    var body: some View {
        List {
            Section {
                LabeledContent("認可状態", value: ScreenTimeFormat.label(for: model.authorizationStatus))
                LabeledContent("選択中", value: ScreenTimeFormat.summary(
                    applications: model.selection.applicationTokens.count,
                    categories: model.selection.categoryTokens.count,
                    webDomains: model.selection.webDomainTokens.count
                ))
            } header: {
                Text("現在の状態")
            } footer: {
                Text("まず「認可」で承認を取ってから、他の項目を試してください。")
            }

            Section("FamilyControls") {
                NavigationLink {
                    ScreenTimeAuthorizationView(model: model)
                } label: {
                    ScreenTimeRow(
                        title: "認可 (AuthorizationCenter)",
                        subtitle: "individual / child で認可を要求・取り消し、状態の変化を監視します。",
                        systemImage: "lock.shield"
                    )
                }
                NavigationLink {
                    ScreenTimeActivityPickerView(model: model)
                } label: {
                    ScreenTimeRow(
                        title: "アプリ選択 (FamilyActivityPicker)",
                        subtitle: "制限対象のアプリ・カテゴリ・Web ドメインを選び、トークンを表示します。",
                        systemImage: "checklist"
                    )
                }
            }

            Section("ManagedSettings") {
                NavigationLink {
                    ScreenTimeShieldView(model: model)
                } label: {
                    ScreenTimeRow(
                        title: "シールド (shield)",
                        subtitle: "選んだアプリ・カテゴリ・Web ドメインを実際にブロックします。",
                        systemImage: "shield.lefthalf.filled"
                    )
                }
                NavigationLink {
                    ScreenTimeSettingsView(model: model)
                } label: {
                    ScreenTimeRow(
                        title: "各種制限設定",
                        subtitle: "アプリ削除禁止・レーティング・Siri・Game Center など端末の制限を切り替えます。",
                        systemImage: "slider.horizontal.3"
                    )
                }
            }

            Section("DeviceActivity") {
                NavigationLink {
                    ScreenTimeDeviceActivityView(model: model)
                } label: {
                    ScreenTimeRow(
                        title: "利用状況モニタリング",
                        subtitle: "スケジュールとしきい値イベントを登録し、監視を開始・停止します。",
                        systemImage: "clock.arrow.2.circlepath"
                    )
                }
            }

            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("Screen Time API")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ScreenTimeRow: View {
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

/// Log section reused by every Screen Time screen.
struct ScreenTimeLogSection: View {
    let model: ScreenTimeTrialModel

    var body: some View {
        Section {
            if model.log.isEmpty {
                Text("ログなし").foregroundStyle(.secondary)
            }
            ForEach(model.log.prefix(30)) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.message)
                        .font(.caption)
                }
            }
        } header: {
            HStack {
                Text("ログ")
                Spacer()
                Button("クリア") { model.clearLog() }
                    .font(.caption)
                    .disabled(model.log.isEmpty)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScreenTimeTrialView()
    }
}
