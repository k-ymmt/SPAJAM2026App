//
//  ScreenTimeActivityPickerView.swift
//  SPAJAM2026App
//

import FamilyControls
import ManagedSettings
import SwiftUI

/// Trial of `FamilyActivityPicker`: pick apps/categories/web domains and
/// look at what the opaque tokens let us render.
struct ScreenTimeActivityPickerView: View {
    @Bindable var model: ScreenTimeTrialModel
    @State private var isPickerPresented = false
    @State private var showsInlinePicker = false

    var body: some View {
        Form {
            Section {
                Button("ピッカーをシートで開く", systemImage: "checklist") { isPickerPresented = true }
                    .disabled(!model.isAuthorized)
                Toggle("ピッカーをインライン表示", isOn: $showsInlinePicker)
                    .disabled(!model.isAuthorized)
                Toggle("includeEntireCategory", isOn: $model.includeEntireCategory)
                    .onChange(of: model.includeEntireCategory) { _, _ in model.applyIncludeEntireCategory() }
                Button("選択をリセット", systemImage: "trash", role: .destructive) { model.resetSelection() }
            } header: {
                Text("FamilyActivityPicker")
            } footer: {
                Text("includeEntireCategory を true にすると、カテゴリ選択時にそのカテゴリ内の全アプリ・Web ドメインのトークンも selection に含まれます。")
            }

            if showsInlinePicker {
                Section("インラインピッカー") {
                    FamilyActivityPicker(
                        headerText: "制限したいものを選ぶ",
                        footerText: "ここで選んだ内容は他の画面でも使われます。",
                        selection: $model.selection
                    )
                    .frame(height: 420)
                }
            }

            Section {
                LabeledContent("合計", value: ScreenTimeFormat.summary(
                    applications: model.selection.applicationTokens.count,
                    categories: model.selection.categoryTokens.count,
                    webDomains: model.selection.webDomainTokens.count
                ))
                LabeledContent("applications (Application)", value: "\(model.selection.applications.count)")
                LabeledContent("categories (ActivityCategory)", value: "\(model.selection.categories.count)")
                LabeledContent("webDomains (WebDomain)", value: "\(model.selection.webDomains.count)")
                LabeledContent("includeEntireCategory", value: model.selection.includeEntireCategory ? "true" : "false")
            } header: {
                Text("FamilyActivitySelection")
            } footer: {
                Text("トークンは不透明な値で、アプリ名やバンドル ID は原則取得できません。表示には `Label(token)` を使います。")
            }

            tokenSection(title: "ApplicationToken", tokens: Array(model.selection.applicationTokens)) { token in
                Label(token)
            }
            tokenSection(title: "ActivityCategoryToken", tokens: Array(model.selection.categoryTokens)) { token in
                Label(token)
            }
            tokenSection(title: "WebDomainToken", tokens: Array(model.selection.webDomainTokens)) { token in
                Label(token)
            }

            Section {
                ForEach(Array(model.selection.applications), id: \.self) { app in
                    VStack(alignment: .leading) {
                        Text(app.localizedDisplayName ?? "(localizedDisplayName なし)")
                        Text(app.bundleIdentifier ?? "(bundleIdentifier なし)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                ForEach(Array(model.selection.webDomains), id: \.self) { domain in
                    Text(domain.domain ?? "(domain なし)")
                        .font(.caption.monospaced())
                }
            } header: {
                Text("Application / WebDomain の生の値")
            } footer: {
                Text("個人向け認可(individual)ではプライバシー保護のため、ほぼすべて nil になります。")
            }

            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("アプリ選択")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $model.selection)
        .onChange(of: model.selection) { _, new in
            model.append("選択が変化: " + ScreenTimeFormat.summary(
                applications: new.applicationTokens.count,
                categories: new.categoryTokens.count,
                webDomains: new.webDomainTokens.count
            ))
        }
    }

    private func tokenSection<T: Hashable, Content: View>(
        title: String,
        tokens: [T],
        @ViewBuilder label: @escaping (T) -> Content
    ) -> some View {
        Section("\(title) (\(tokens.count))") {
            if tokens.isEmpty {
                Text("なし").foregroundStyle(.secondary)
            }
            ForEach(tokens, id: \.self) { token in
                label(token)
            }
        }
    }
}
