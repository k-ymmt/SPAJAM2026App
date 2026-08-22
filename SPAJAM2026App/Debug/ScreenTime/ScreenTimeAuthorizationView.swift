//
//  ScreenTimeAuthorizationView.swift
//  SPAJAM2026App
//

import FamilyControls
import SwiftUI

/// Trial of `AuthorizationCenter`: request / revoke and watch status changes.
struct ScreenTimeAuthorizationView: View {
    @Bindable var model: ScreenTimeTrialModel

    var body: some View {
        Form {
            Section {
                LabeledContent("authorizationStatus", value: ScreenTimeFormat.label(for: model.authorizationStatus))
                Button("状態を再取得", systemImage: "arrow.clockwise") { model.refreshAuthorization() }
            } header: {
                Text("現在の状態")
            } footer: {
                Text("`$authorizationStatus` の Publisher も購読しているので、設定アプリ側で変えた場合もログに出ます。")
            }

            Section {
                Picker("FamilyControlsMember", selection: $model.member) {
                    Text(ScreenTimeFormat.label(for: .individual)).tag(FamilyControlsMember.individual)
                    Text(ScreenTimeFormat.label(for: .child)).tag(FamilyControlsMember.child)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Button {
                    model.requestAuthorization()
                } label: {
                    HStack {
                        Label("requestAuthorization(for:)", systemImage: "hand.raised.fill")
                        if model.isRequesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRequesting)
            } header: {
                Text("認可を要求")
            } footer: {
                Text("individual は端末の利用者本人向け(iOS 16+)。child はファミリー共有の子ども用端末で保護者の承認が必要です。")
            }

            Section {
                Button("revokeAuthorization", systemImage: "xmark.shield", role: .destructive) {
                    model.revokeAuthorization()
                }
                .disabled(!model.isAuthorized)
            } header: {
                Text("認可の取り消し")
            } footer: {
                Text("取り消すと ManagedSettings による制限はすべて解除され、DeviceActivity の監視も止まります。")
            }

            ScreenTimeLogSection(model: model)
        }
        .navigationTitle("認可")
        .navigationBarTitleDisplayMode(.inline)
    }
}
