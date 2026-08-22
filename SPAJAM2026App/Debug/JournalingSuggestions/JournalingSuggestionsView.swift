//
//  JournalingSuggestionsView.swift
//  SPAJAM2026App
//
//  Trial screen for the JournalingSuggestions framework: pick a suggestion with
//  the system picker and list what it contains.
//

import SwiftUI

struct JournalingSuggestionsView: View {
    @State private var entries: [SuggestionEntry] = []
    @State private var isPickerPresented = false

    var body: some View {
        VStack(spacing: 0) {
            pickerButton
            Divider()
            pickedList
        }
        .navigationTitle("Journaling Suggestions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !entries.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("すべて消去", systemImage: "trash") {
                        withAnimation { entries.removeAll() }
                    }
                }
            }
        }
        .suggestionPicker(isPresented: $isPickerPresented) { entry in
            withAnimation { entries.insert(entry, at: 0) }
        }
    }

    private var pickerButton: some View {
        VStack(spacing: 8) {
            Button {
                isPickerPresented = true
            } label: {
                Label("候補を選ぶ", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.background)
    }

    private var footnote: String {
        isSystemSuggestionPickerAvailable
            ? "ボタンを押すとシステムの Journaling Suggestions ピッカーが開きます。選んだ候補が下に追加されます。"
            : "シミュレータでは JournalingSuggestions を利用できません。サンプル候補で動作を確認できます。"
    }

    @ViewBuilder
    private var pickedList: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "まだ候補がありません",
                systemImage: "text.book.closed",
                description: Text("上のボタンから候補を選ぶと、ここに一覧表示されます。")
            )
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(entries) { entry in
                    Section {
                        if entry.items.isEmpty {
                            Text("含まれるコンテンツはありません")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(entry.items) { item in
                                SuggestionItemRow(item: item)
                            }
                        }
                    } header: {
                        SuggestionEntryHeader(entry: entry) {
                            withAnimation { entries.removeAll { $0.id == entry.id } }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct SuggestionEntryHeader: View {
    let entry: SuggestionEntry
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)
                if let interval = entry.dateInterval {
                    Text(SuggestionFormat.interval(interval))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                Text("\(entry.items.count) 件のコンテンツ・選択 \(SuggestionFormat.date(entry.pickedAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .textCase(nil)
            }
            Spacer()
            Button("削除", systemImage: "xmark.circle.fill", action: onDelete)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SuggestionItemRow: View {
    let item: SuggestionItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(item.kind.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(item.headline)
                    .font(.body)
                ForEach(Array(item.details.enumerated()), id: \.offset) { _, detail in
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.imageURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholderIcon
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholderIcon
                .frame(width: 44, height: 44)
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .overlay {
                Image(systemName: item.kind.symbolName)
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview("空の状態") {
    NavigationStack {
        JournalingSuggestionsView()
    }
}

#Preview("選択済み") {
    NavigationStack {
        List {
            ForEach(SampleSuggestions.all) { entry in
                Section {
                    ForEach(entry.items) { SuggestionItemRow(item: $0) }
                } header: {
                    SuggestionEntryHeader(entry: entry) {}
                }
            }
        }
        .navigationTitle("Journaling Suggestions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
