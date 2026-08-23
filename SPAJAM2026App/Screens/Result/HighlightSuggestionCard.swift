//
//  HighlightSuggestionCard.swift
//  SPAJAM2026App
//
//  リザルト「旅のハイライト」: iOS の Journaling Suggestions から選んだ候補の項目をすべて並べる。
//  JournalingSuggestions はシステムピッカー経由でしか取得できないため、カードをタップして選ぶ。
//  シミュレータ(フレームワーク無し)ではサンプル候補ピッカーに切り替わる。
//

import SwiftUI

struct HighlightSuggestionCard: View {
    @State private var entry: SuggestionEntry?
    @State private var isPickerPresented = false

    /// 選んだ候補の項目(種類を問わずすべて)
    private var items: [SuggestionItem] {
        entry?.items ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image("DoodlePen")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 24)
                Text("旅のハイライト")
                    .font(.handTitle)
                    .foregroundStyle(Color.inkMain)
                Spacer()
                if entry != nil {
                    Button("えらびなおす") { isPickerPresented = true }
                        .font(.handCaption2)
                        .foregroundStyle(Color.appAccent)
                }
            }
            if items.isEmpty {
                placeholder
            } else {
                itemGrid
            }
        }
        .suggestionPicker(isPresented: $isPickerPresented) { picked in
            withAnimation { entry = picked }
        }
    }

    private var placeholder: some View {
        Button { isPickerPresented = true } label: {
            VStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.appAccent)
                Text(entry == nil ? "iOS のおすすめからえらぶ" : "この候補に項目はありませんでした")
                    .font(.handBody)
                    .foregroundStyle(Color.inkMain)
                Text(isSystemSuggestionPickerAvailable
                     ? "タップするとジャーナル候補のピッカーが開きます"
                     : "シミュレータではサンプル候補を表示します")
                    .font(.handCaption2)
                    .foregroundStyle(Color.inkSub)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 30))
        }
        .buttonStyle(.plain)
    }

    private var itemGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(items) { item in
                    itemTile(item)
                }
            }
        }
        .frame(height: 294)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    private func itemTile(_ item: SuggestionItem) -> some View {
        Group {
            if let url = item.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().tint(Color.appAccent)
                }
            } else {
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 40))
                    .foregroundStyle(Color.inkSub)
            }
        }
        .frame(width: 340, height: 294)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
}
