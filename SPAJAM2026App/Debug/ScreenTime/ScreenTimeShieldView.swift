//
//  ScreenTimeShieldView.swift
//  SPAJAM2026App
//

import FamilyControls
import ManagedSettings
import SwiftUI

/// Trial of `ManagedSettingsStore.shield`: block the picked apps, categories
/// and web domains for real.
struct ScreenTimeShieldView: View {
    enum CategoryPolicy: String, CaseIterable, Identifiable {
        case none, specific, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: "なし (.none)"
            case .specific: "選んだカテゴリ (.specific)"
            case .all: "すべて (.all)"
            }
        }
    }

    @Bindable var model: ScreenTimeTrialModel
    @State private var shieldApplications = false
    @State private var shieldWebDomains = false
    @State private var appCategoryPolicy: CategoryPolicy = .none
    @State private var webCategoryPolicy: CategoryPolicy = .none
    @State private var exceptSelectedApps = false
    @State private var exceptSelectedDomains = false

    var body: some View {
        Form {
            Section {
                TextField("ストア名(空でデフォルト)", text: $model.storeName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("ストアを切り替え", systemImage: "arrow.triangle.swap") {
                    model.switchStore()
                    readBack()
                }
            } header: {
                Text("ManagedSettingsStore")
            } footer: {
                Text("名前付きストアごとに独立して設定を持てます(最大 50 個)。同じ名前なら別プロセス(拡張)からも同じ設定を参照します。")
            }

            Section {
                LabeledContent("選択中", value: ScreenTimeFormat.summary(
                    applications: model.selection.applicationTokens.count,
                    categories: model.selection.categoryTokens.count,
                    webDomains: model.selection.webDomainTokens.count
                ))
                Toggle("shield.applications に選択アプリを設定", isOn: $shieldApplications)
                Toggle("shield.webDomains に選択ドメインを設定", isOn: $shieldWebDomains)
            } header: {
                Text("個別シールド")
            }

            Section {
                Picker("shield.applicationCategories", selection: $appCategoryPolicy) {
                    ForEach(CategoryPolicy.allCases) { Text($0.label).tag($0) }
                }
                Toggle("選択アプリを except に入れる", isOn: $exceptSelectedApps)
                    .disabled(appCategoryPolicy == .none)
                Picker("shield.webDomainCategories", selection: $webCategoryPolicy) {
                    ForEach(CategoryPolicy.allCases) { Text($0.label).tag($0) }
                }
                Toggle("選択ドメインを except に入れる", isOn: $exceptSelectedDomains)
                    .disabled(webCategoryPolicy == .none)
            } header: {
                Text("カテゴリシールド (ActivityCategoryPolicy)")
            } footer: {
                Text(".all(except:) で「選んだもの以外を全部ブロック」ができます。")
            }

            Section {
                Button {
                    apply()
                } label: {
                    Label("シールドを適用", systemImage: "shield.lefthalf.filled")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.isAuthorized)
                Button("シールドだけ解除", systemImage: "shield.slash") { clearShield() }
                Button("clearAllSettings()", systemImage: "trash", role: .destructive) {
                    model.clearAllSettings()
                    readBack()
                }
            } footer: {
                Text("適用後にホーム画面でブロック対象のアプリを開くと、システム標準のシールド画面が表示されます。(カスタマイズには ShieldConfiguration 拡張が必要)")
            }

            Section("ストアの現在値") {
                LabeledContent("shield.applications", value: "\(model.store.shield.applications?.count.description ?? "nil")")
                LabeledContent("shield.webDomains", value: "\(model.store.shield.webDomains?.count.description ?? "nil")")
                LabeledContent("shield.applicationCategories", value: describe(model.store.shield.applicationCategories))
                LabeledContent("shield.webDomainCategories", value: describe(model.store.shield.webDomainCategories))
                Button("再読込", systemImage: "arrow.clockwise") { readBack() }
            }

            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("シールド")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { readBack() }
    }

    private func apply() {
        let store = model.store
        let selection = model.selection
        store.shield.applications = shieldApplications && !selection.applicationTokens.isEmpty ? selection.applicationTokens : nil
        store.shield.webDomains = shieldWebDomains && !selection.webDomainTokens.isEmpty ? selection.webDomainTokens : nil

        let appExcept = exceptSelectedApps ? selection.applicationTokens : []
        store.shield.applicationCategories = switch appCategoryPolicy {
        case .none: nil
        case .specific: .specific(selection.categoryTokens, except: appExcept)
        case .all: .all(except: appExcept)
        }
        let webExcept = exceptSelectedDomains ? selection.webDomainTokens : []
        store.shield.webDomainCategories = switch webCategoryPolicy {
        case .none: nil
        case .specific: .specific(selection.categoryTokens, except: webExcept)
        case .all: .all(except: webExcept)
        }
        model.append("シールド適用: apps=\(shieldApplications) web=\(shieldWebDomains) appCat=\(appCategoryPolicy.rawValue) webCat=\(webCategoryPolicy.rawValue)")
        readBack()
    }

    private func clearShield() {
        let store = model.store
        store.shield.applications = nil
        store.shield.webDomains = nil
        store.shield.applicationCategories = nil
        store.shield.webDomainCategories = nil
        model.append("シールド解除")
        readBack()
    }

    private func readBack() {
        let shield = model.store.shield
        shieldApplications = shield.applications != nil
        shieldWebDomains = shield.webDomains != nil
        appCategoryPolicy = policy(shield.applicationCategories)
        webCategoryPolicy = policy(shield.webDomainCategories)
    }

    private func policy<T>(_ value: ShieldSettings.ActivityCategoryPolicy<T>?) -> CategoryPolicy {
        switch value {
        case .none: .none
        case .some(.all): .all
        case .some(.specific): .specific
        case .some: .none
        }
    }

    private func describe<T>(_ value: ShieldSettings.ActivityCategoryPolicy<T>?) -> String {
        switch value {
        case .none: "nil"
        case .some(.all(let except)): "all(except: \(except.count))"
        case .some(.specific(let set, let except)): "specific(\(set.count), except: \(except.count))"
        case .some: "other"
        }
    }
}
