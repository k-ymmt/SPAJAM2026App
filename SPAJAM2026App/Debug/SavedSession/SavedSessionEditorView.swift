//
//  SavedSessionEditorView.swift
//  SPAJAM2026App
//
//  デバッグ用: 永続化された TripSession のスナップショットを表示・編集・クリアする。
//  保存すると TripSessionStore.didChange が通知され、ルート画面が保存内容でセッションを作り直す。
//

import SwiftUI

struct SavedSessionEditorView: View {
    @State private var snapshot: TripSessionSnapshot?
    @State private var confirmClear = false
    @State private var savedBanner = false

    var body: some View {
        List {
            if let binding = Binding($snapshot) {
                editor(binding)
            } else {
                Section {
                    ContentUnavailableView(
                        "保存セッションなし",
                        systemImage: "tray",
                        description: Text("エリアを選んで旅を始めると保存されます。ここからデモプランで新規作成もできます。")
                    )
                    Button("デモプランで新規作成") {
                        snapshot = TripSession(plan: .bundledDemoPlan()).snapshot
                    }
                }
            }
        }
        .navigationTitle("保存セッション")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("保存") { save() }
                    .disabled(snapshot == nil)
                Button("クリア", role: .destructive) { confirmClear = true }
                    .disabled(TripSessionStore.load() == nil && snapshot == nil)
            }
        }
        .confirmationDialog("保存セッションをクリアしますか?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("クリアする", role: .destructive) { clear() }
        } message: {
            Text("ルート画面はエリア選択に戻ります。")
        }
        .overlay(alignment: .bottom) {
            if savedBanner {
                Text("保存しました")
                    .font(.footnote.bold())
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { snapshot = TripSessionStore.load() }
    }

    // MARK: - 編集フォーム

    @ViewBuilder
    private func editor(_ s: Binding<TripSessionSnapshot>) -> some View {
        let plan = s.wrappedValue.plan

        Section("進行状態") {
            LabeledContent("プラン", value: "\(plan.title) (\(plan.planId))")
            Picker("フェーズ", selection: s.phase) {
                Text("プラン確認").tag(TripSessionSnapshot.Phase.planning)
                Text("おやすみ設定").tag(TripSessionSnapshot.Phase.restrictionSetup)
                Text("旅行中").tag(TripSessionSnapshot.Phase.traveling)
                Text("終了").tag(TripSessionSnapshot.Phase.finished)
            }
            Picker("現在ミッション", selection: s.currentMissionId) {
                Text("なし").tag(String?.none)
                ForEach(plan.missions) { m in
                    Text("\(m.order). \(m.title)").tag(String?.some(m.id))
                }
            }
            Toggle("Mock 判定を使う", isOn: s.useMockJudge)
        }

        Section("達成ミッション") {
            ForEach(plan.missions) { mission in
                Toggle(isOn: achievedBinding(s, mission: mission)) {
                    VStack(alignment: .leading) {
                        Text("\(mission.order). \(mission.title)")
                        Text("\(mission.category.label) / \(mission.points) pt")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }

        Section("時間(OFFLINE SCORE)") {
            optionalDate("旅行開始", s.tripStartedAt)
            optionalDate("旅行終了", s.tripEndedAt)
            Stepper(
                "前面時間: \(Int(s.wrappedValue.foregroundSeconds / 60)) 分",
                value: Binding(
                    get: { s.wrappedValue.foregroundSeconds / 60 },
                    set: { s.wrappedValue.foregroundSeconds = max(0, $0) * 60 }
                ),
                step: 1
            )
            Stepper("制限調整回数: \(s.wrappedValue.restrictionAdjustments)", value: s.restrictionAdjustments, in: 0...100)
            if let active = s.wrappedValue.becameActiveAt {
                LabeledContent("前面開始", value: active.formatted(date: .omitted, time: .standard))
            }
        }

        Section("心拍サンプル(HEART SCORE)") {
            LabeledContent("件数", value: "\(s.wrappedValue.heartRateSamples.count)")
            Button("ランダムに 10 件追加") {
                let now = Date()
                s.wrappedValue.heartRateSamples += (0..<10).map {
                    HeartRateSample(date: now.addingTimeInterval(Double($0) * 30), bpm: Double(Int.random(in: 65...120)))
                }
            }
            Button("全消去", role: .destructive) { s.wrappedValue.heartRateSamples = [] }
                .disabled(s.wrappedValue.heartRateSamples.isEmpty)
        }

        Section("その他") {
            LabeledContent(
                "シールド選択",
                value: s.wrappedValue.shieldSelectionData.map { "あり(\($0.count) bytes)" } ?? "なし"
            )
            Button("シールド選択を消す", role: .destructive) { s.wrappedValue.shieldSelectionData = nil }
                .disabled(s.wrappedValue.shieldSelectionData == nil)
            LabeledContent("最終保存", value: s.wrappedValue.savedAt.formatted(date: .numeric, time: .standard))
        }
    }

    @ViewBuilder
    private func optionalDate(_ title: String, _ date: Binding<Date?>) -> some View {
        Toggle(title, isOn: Binding(
            get: { date.wrappedValue != nil },
            set: { date.wrappedValue = $0 ? Date() : nil }
        ))
        if let d = Binding(date) {
            DatePicker("", selection: d)
                .labelsHidden()
        }
    }

    private func achievedBinding(_ s: Binding<TripSessionSnapshot>, mission: Mission) -> Binding<Bool> {
        Binding(
            get: { s.wrappedValue.records.contains { $0.missionId == mission.id } },
            set: { on in
                if on {
                    guard !s.wrappedValue.records.contains(where: { $0.missionId == mission.id }) else { return }
                    s.wrappedValue.records.append(MissionRecord(
                        missionId: mission.id,
                        achievedAt: Date(),
                        photoFileName: nil,
                        bpmAtAchieve: nil,
                        points: mission.points,
                        aiComment: "(デバッグで達成扱い)"
                    ))
                } else {
                    s.wrappedValue.records.removeAll { $0.missionId == mission.id }
                }
            }
        )
    }

    // MARK: - 操作

    private func save() {
        guard var snapshot else { return }
        snapshot.savedAt = Date()
        self.snapshot = snapshot
        TripSessionStore.save(snapshot)
        TripSessionStore.notifyChanged()
        withAnimation { savedBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { savedBanner = false }
        }
    }

    private func clear() {
        TripSessionStore.clear()
        TripSessionStore.notifyChanged()
        snapshot = nil
    }
}

#Preview {
    NavigationStack { SavedSessionEditorView() }
}
