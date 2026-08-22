//
//  InviteCodeJoinView.swift
//  SPAJAM2026App
//
//  招待コード入力ダイアログ。ユーザー名と招待コードを入力して子として参加する。
//  他画面と同じクリーム背景 + 白カード + 手書きフォントで統一。
//

import SwiftUI

struct InviteCodeJoinView: View {
    /// 参加ボタン。成功なら dismiss、失敗ならエラー文言を返す
    var onJoin: (_ name: String, _ code: String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var code = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case name, code }

    private var canJoin: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && InviteCode.normalize(code) != nil && !isJoining
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenHeader("招待コードを入力", subtitle: "プランを作る人に表示された 6 文字のコードを入力してください") {
                HeaderIconButton(systemName: "xmark") { dismiss() }
            }

            VStack(alignment: .leading, spacing: 16) {
                field("ユーザー名", placeholder: "例: たろう", text: $name)
                    .focused($focus, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focus = .code }

                field("招待コード", placeholder: "ABC234", text: $code)
                    .focused($focus, equals: .code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.handNumber(22))
                    .submitLabel(.go)
                    .onSubmit { if canJoin { join() } }
            }
            .padding(18)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.06), radius: 9, y: 6)

            if let errorMessage {
                Text(errorMessage)
                    .font(.handCaption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
            }

            Spacer()

            VStack(spacing: 10) {
                Button(action: join) {
                    HStack(spacing: 8) {
                        if isJoining { ProgressView().tint(.white) }
                        Text("参加する")
                    }
                    .font(.handHeadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!canJoin)

                Text("参加すると、プランができるまで待機画面になります")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
        .onAppear { focus = .name }
        .interactiveDismissDisabled(isJoining)
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.handCaption)
                .foregroundStyle(Color.inkSub)
            TextField(placeholder, text: text)
                .font(.handBody)
                .foregroundStyle(Color.inkMain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(red: 0.98, green: 0.965, blue: 0.94), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: 1))
        }
    }

    private func join() {
        guard canJoin, let normalized = InviteCode.normalize(code) else { return }
        isJoining = true
        errorMessage = nil
        Task {
            if let message = await onJoin(name, normalized) {
                errorMessage = message
            } else {
                dismiss()
            }
            isJoining = false
        }
    }
}

#Preview {
    InviteCodeJoinView { _, _ in nil }
}
