//
//  ScreenTimeSettingsView.swift
//  SPAJAM2026App
//

import FamilyControls
import ManagedSettings
import SwiftUI

/// Trial of the other `ManagedSettingsStore` groups: application, media,
/// appStore, webContent, siri, gameCenter, passcode, account, cellular,
/// dateAndTime and safari.
struct ScreenTimeSettingsView: View {
    @Bindable var model: ScreenTimeTrialModel

    var body: some View {
        Form {
            applicationSection
            mediaSection
            appStoreSection
            webContentSection
            miscSection
            Section {
                Button("clearAllSettings()", systemImage: "trash", role: .destructive) {
                    model.clearAllSettings()
                }
            } footer: {
                Text("各トグルはストアへ即時反映されます。nil は「制限しない」を意味します。")
            }
            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("各種制限設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var store: ManagedSettingsStore { model.store }

    // MARK: Sections

    private var applicationSection: some View {
        Section {
            optionalToggle("denyAppRemoval", get: { store.application.denyAppRemoval }, set: { store.application.denyAppRemoval = $0 })
            optionalToggle("denyAppInstallation", get: { store.application.denyAppInstallation }, set: { store.application.denyAppInstallation = $0 })
            Toggle("blockedApplications に選択アプリを設定", isOn: Binding(
                get: { store.application.blockedApplications != nil },
                set: { on in
                    store.application.blockedApplications = on ? model.selection.applications : nil
                    model.append("application.blockedApplications = \(on ? "\(model.selection.applications.count) 件" : "nil")")
                }
            ))
        } header: {
            Text("application")
        } footer: {
            Text("blockedApplications はアプリをホーム画面から非表示にします(shield と異なりアイコン自体が消えます)。")
        }
    }

    private var mediaSection: some View {
        Section("media") {
            optionalToggle("denyExplicitContent", get: { store.media.denyExplicitContent }, set: { store.media.denyExplicitContent = $0 })
            optionalToggle("denyBookstoreErotica", get: { store.media.denyBookstoreErotica }, set: { store.media.denyBookstoreErotica = $0 })
            optionalRating("maximumMovieRating", max: 1000, get: { store.media.maximumMovieRating }, set: { store.media.maximumMovieRating = $0 })
            optionalRating("maximumTVShowRating", max: 1000, get: { store.media.maximumTVShowRating }, set: { store.media.maximumTVShowRating = $0 })
        }
    }

    private var appStoreSection: some View {
        Section("appStore") {
            optionalToggle("denyInAppPurchases", get: { store.appStore.denyInAppPurchases }, set: { store.appStore.denyInAppPurchases = $0 })
            optionalRating("maximumRating", max: 1000, get: { store.appStore.maximumRating }, set: { store.appStore.maximumRating = $0 })
            Picker("requirePasswordForPurchases", selection: Binding(
                get: { store.appStore.requirePasswordForPurchases ?? false },
                set: {
                    store.appStore.requirePasswordForPurchases = $0
                    model.append("appStore.requirePasswordForPurchases = \($0)")
                }
            )) {
                Text("false").tag(false)
                Text("true").tag(true)
            }
        }
    }

    private var webContentSection: some View {
        Section {
            Picker("blockedByFilter", selection: Binding(
                get: { filterLabel(store.webContent.blockedByFilter) },
                set: { setFilter($0) }
            )) {
                Text("nil").tag("nil")
                Text("auto(選択ドメイン以外も自動)").tag("auto")
                Text("specific(選択ドメインのみ)").tag("specific")
                Text("all(選択ドメイン以外)").tag("all")
                Text("none").tag("none")
            }
        } header: {
            Text("webContent")
        } footer: {
            Text("auto はアダルトサイトの自動フィルタに加えて、指定ドメインをブロックします。")
        }
    }

    private var miscSection: some View {
        Section("その他のグループ") {
            optionalToggle("siri.denySiri", get: { store.siri.denySiri }, set: { store.siri.denySiri = $0 })
            optionalToggle("gameCenter.denyMultiplayerGaming", get: { store.gameCenter.denyMultiplayerGaming }, set: { store.gameCenter.denyMultiplayerGaming = $0 })
            optionalToggle("gameCenter.denyAddingFriends", get: { store.gameCenter.denyAddingFriends }, set: { store.gameCenter.denyAddingFriends = $0 })
            optionalToggle("passcode.lockPasscode", get: { store.passcode.lockPasscode }, set: { store.passcode.lockPasscode = $0 })
            optionalToggle("account.lockAccounts", get: { store.account.lockAccounts }, set: { store.account.lockAccounts = $0 })
            optionalToggle("cellular.lockAppCellularData", get: { store.cellular.lockAppCellularData }, set: { store.cellular.lockAppCellularData = $0 })
            optionalToggle("cellular.lockCellularPlan", get: { store.cellular.lockCellularPlan }, set: { store.cellular.lockCellularPlan = $0 })
            optionalToggle("cellular.lockESIM", get: { store.cellular.lockESIM }, set: { store.cellular.lockESIM = $0 })
            optionalToggle("dateAndTime.requireAutomaticDateAndTime", get: { store.dateAndTime.requireAutomaticDateAndTime }, set: { store.dateAndTime.requireAutomaticDateAndTime = $0 })
            optionalToggle("safari.denyAutoFill", get: { store.safari.denyAutoFill }, set: { store.safari.denyAutoFill = $0 })
        }
    }

    // MARK: Helpers

    private func optionalToggle(_ title: String, get: @escaping () -> Bool?, set: @escaping (Bool?) -> Void) -> some View {
        Toggle(title, isOn: Binding(
            get: { get() ?? false },
            set: { on in
                set(on ? true : nil)
                model.append("\(title) = \(on ? "true" : "nil")")
            }
        ))
        .font(.callout)
    }

    private func optionalRating(_ title: String, max: Int, get: @escaping () -> Int?, set: @escaping (Int?) -> Void) -> some View {
        Picker(title, selection: Binding(
            get: { get() ?? -1 },
            set: { value in
                set(value < 0 ? nil : value)
                model.append("\(title) = \(value < 0 ? "nil" : String(value))")
            }
        )) {
            Text("nil").tag(-1)
            Text("0(すべて不可)").tag(0)
            Text("100").tag(100)
            Text("200").tag(200)
            Text("300").tag(300)
            Text("400").tag(400)
            Text("500").tag(500)
            Text("600").tag(600)
            Text("\(max)(すべて可)").tag(max)
        }
        .font(.callout)
    }

    private func filterLabel(_ policy: WebContentSettings.FilterPolicy?) -> String {
        switch policy {
        case nil: "nil"
        case .auto: "auto"
        case .specific: "specific"
        case .all: "all"
        case .none: "none"
        case .some: "nil"
        }
    }

    private func setFilter(_ label: String) {
        let domains = model.selection.webDomains
        switch label {
        case "auto": store.webContent.blockedByFilter = .auto(domains, except: [])
        case "specific": store.webContent.blockedByFilter = .specific(domains)
        case "all": store.webContent.blockedByFilter = .all(except: domains)
        case "none": store.webContent.blockedByFilter = WebContentSettings.FilterPolicy.none
        default: store.webContent.blockedByFilter = nil
        }
        model.append("webContent.blockedByFilter = \(label) (domains=\(domains.count))")
    }
}
