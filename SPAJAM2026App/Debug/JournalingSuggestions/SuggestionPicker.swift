//
//  SuggestionPicker.swift
//  SPAJAM2026App
//
//  Presents the system Journaling Suggestions picker on device, and a sample
//  picker with the same shape on the simulator (where the framework is absent).
//

import SwiftUI

#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

extension View {
    /// Presents a suggestion picker and reports the picked suggestion as a `SuggestionEntry`.
    func suggestionPicker(
        isPresented: Binding<Bool>,
        onPick: @escaping (SuggestionEntry) -> Void
    ) -> some View {
        modifier(SuggestionPickerModifier(isPresented: isPresented, onPick: onPick))
    }
}

/// Whether the real system picker is available in this build.
let isSystemSuggestionPickerAvailable: Bool = {
#if canImport(JournalingSuggestions)
    true
#else
    false
#endif
}()

private struct SuggestionPickerModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onPick: (SuggestionEntry) -> Void

    func body(content: Content) -> some View {
#if canImport(JournalingSuggestions)
        content.journalingSuggestionsPicker(isPresented: $isPresented) { suggestion in
            onPick(await SuggestionEntry(suggestion: suggestion))
        }
#else
        content.sheet(isPresented: $isPresented) {
            SampleSuggestionPicker(onPick: onPick)
        }
#endif
    }
}

/// Stand-in for the system picker so the flow stays testable in the simulator.
struct SampleSuggestionPicker: View {
    let onPick: (SuggestionEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SampleSuggestions.all) { entry in
                Button {
                    onPick(entry.refreshed())
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.title)
                            .font(.headline)
                        if let interval = entry.dateInterval {
                            Text(SuggestionFormat.interval(interval))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 10) {
                            ForEach(entry.items) { item in
                                Label(item.kind.label, systemImage: item.kind.symbolName)
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("サンプル候補")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top) {
                Text("シミュレータでは JournalingSuggestions が利用できないため、サンプルデータを表示しています。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.bar)
            }
        }
    }
}
