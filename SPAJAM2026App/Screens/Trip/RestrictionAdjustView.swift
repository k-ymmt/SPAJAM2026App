//
//  RestrictionAdjustView.swift
//  SPAJAM2026App
//
//  旅行中の制限調整。おやすみ対象を変更できるが、1 回につき OFFLINE SCORE -5pt。
//

import SwiftUI
#if canImport(FamilyControls)
import FamilyControls
#endif

struct RestrictionAdjustView: View {
    @Environment(TripSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule().fill(Color(.systemGray4)).frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)

            Text("制限をととのえる")
                .font(.handTitle)

            // ペナルティの警告
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.appAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("調整すると OFFLINE SCORE −5pt")
                        .font(.system(size: 15, weight: .semibold))
                    Text("これまでの調整: \(session.restrictionAdjustments)回(−\(session.adjustPenalty)pt)")
                        .font(.handCaption2)
                        .foregroundStyle(Color.inkSub)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.badgeBackground, in: RoundedRectangle(cornerRadius: 16))

            Button {
                Task {
                    await session.shield.requestAuthorization()
                    if session.shield.isAuthorized { showPicker = true }
                }
            } label: {
                Label("おやすみにするアプリを選び直す", systemImage: "moon.zzz.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .tint(.appAccent)

            Spacer()

            Button {
                session.applyShieldAdjustment()
                dismiss()
            } label: {
                Text("この設定に変更する(−5pt)")
                    .font(.handHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)

            Button {
                dismiss()
            } label: {
                Text("やっぱりやめる(減点なし)")
                    .font(.handCaption)
                    .foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(Color.appBackground)
        #if canImport(FamilyControls)
        .familyActivityPicker(isPresented: $showPicker, selection: Bindable(session.shield).selection)
        #endif
    }
}
