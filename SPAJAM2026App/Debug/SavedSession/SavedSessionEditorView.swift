//
//  SavedSessionEditorView.swift
//  SPAJAM2026App
//
//  デバッグ用: 永続化された TripSession のスナップショットを表示・編集・クリアする。
//  保存すると TripSessionStore.didChange が通知され、ルート画面が保存内容でセッションを作り直す。
//

import PhotosUI
import SwiftUI

struct SavedSessionEditorView: View {
    @State private var snapshot: TripSessionSnapshot?
    @State private var confirmClear = false
    @State private var savedBanner = false
    @State private var shieldClearedBanner = false
    @State private var isShieldApplied = ShieldService.isShieldApplied

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
            if savedBanner || shieldClearedBanner {
                Text(shieldClearedBanner ? "シールドを解除しました" : "保存しました")
                    .font(.footnote.bold())
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            snapshot = TripSessionStore.load()
            isShieldApplied = ShieldService.isShieldApplied
        }
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

        Section {
            ForEach(plan.missions) { mission in
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: achievedBinding(s, mission: mission)) {
                        VStack(alignment: .leading) {
                            Text("\(mission.order). \(mission.title)")
                            Text("\(mission.category.label) / \(mission.points) pt")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    MissionPhotoRow(
                        missionId: mission.id,
                        photoFileName: photoFileNameBinding(s, mission: mission),
                        onPicked: { fileName in
                            // 写真を入れたら達成扱いにして record にひも付ける
                            achievedBinding(s, mission: mission).wrappedValue = true
                            photoFileNameBinding(s, mission: mission).wrappedValue = fileName
                        }
                    )
                }
            }
        } header: {
            Text("達成ミッション")
        } footer: {
            Text("「写真を選ぶ」でフォトライブラリの画像を達成写真として差し込めます(シミュレータでも可)。選ぶと自動で達成 ON になります。")
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
                // リザルトの心拍グラフは旅の時間帯(開始〜終了)を区間に分けて集計するので、
                // サンプルも同じ時間帯に散らす(未開始なら直近 1 時間)
                let end = s.wrappedValue.tripEndedAt ?? Date()
                let start = s.wrappedValue.tripStartedAt ?? end.addingTimeInterval(-3600)
                let span = max(60, end.timeIntervalSince(start))
                s.wrappedValue.heartRateSamples += (0..<10).map { _ in
                    HeartRateSample(
                        date: start.addingTimeInterval(Double.random(in: 0...span)),
                        bpm: Double(Int.random(in: 65...120))
                    )
                }
                s.wrappedValue.heartRateSamples.sort { $0.date < $1.date }
            }
            Button("全消去", role: .destructive) { s.wrappedValue.heartRateSamples = [] }
                .disabled(s.wrappedValue.heartRateSamples.isEmpty)
        }

        Section("その他") {
            Button("シールドを今すぐ解除", role: .destructive) { clearShield() }
                .disabled(!isShieldApplied)
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
                    // 既に Documents に達成写真があればそのままひも付ける
                    let name = "mission-\(mission.id).jpg"
                    let exists = FileManager.default.fileExists(atPath: URL.documentsDirectory.appending(path: name).path)
                    s.wrappedValue.records.append(MissionRecord(
                        missionId: mission.id,
                        achievedAt: Date(),
                        photoFileName: exists ? name : nil,
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

    private func photoFileNameBinding(_ s: Binding<TripSessionSnapshot>, mission: Mission) -> Binding<String?> {
        Binding(
            get: { s.wrappedValue.records.first { $0.missionId == mission.id }?.photoFileName },
            set: { name in
                guard let i = s.wrappedValue.records.firstIndex(where: { $0.missionId == mission.id }) else { return }
                s.wrappedValue.records[i].photoFileName = name
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

    private func clearShield() {
        ShieldService.forceClearAll()
        isShieldApplied = ShieldService.isShieldApplied
        withAnimation { shieldClearedBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation { shieldClearedBanner = false }
        }
    }

    private func clear() {
        TripSessionStore.clear()
        TripSessionStore.notifyChanged()
        snapshot = nil
    }
}

/// ミッション 1 件分の達成写真: サムネイル + フォトライブラリから選ぶ/削除。
/// 保存先は TripSession.saveImage と同じ Documents/mission-<missionId>.jpg。
private struct MissionPhotoRow: View {
    let missionId: String
    @Binding var photoFileName: String?
    var onPicked: (String) -> Void

    @State private var pickerItem: PhotosPickerItem?
    @State private var loading = false

    private var fileURL: URL? {
        photoFileName.map { URL.documentsDirectory.appending(path: $0) }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let url = fileURL, let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 56, height: 56)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(loading ? "読み込み中…" : "写真を選ぶ", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .disabled(loading)
            if photoFileName != nil {
                Button("削除", role: .destructive) { removePhoto() }
                    .font(.subheadline)
                    .buttonStyle(.bordered)
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loading = true
            Task {
                defer { loading = false; pickerItem = nil }
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = image.jpegData(compressionQuality: 0.7) else { return }
                let name = "mission-\(missionId).jpg"
                do {
                    try jpeg.write(to: URL.documentsDirectory.appending(path: name))
                    onPicked(name)
                } catch {
                    print("[SavedSessionEditor] 写真の保存に失敗: \(error)")
                }
            }
        }
    }

    private func removePhoto() {
        if let url = fileURL { try? FileManager.default.removeItem(at: url) }
        photoFileName = nil
    }
}

#Preview {
    NavigationStack { SavedSessionEditorView() }
}
