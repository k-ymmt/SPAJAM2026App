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

    /// 未選択時: 薄緑の枠付きカード(「おすすめから選ぶ」+「+」)
    private var placeholder: some View {
        Button { isPickerPresented = true } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry == nil ? "おすすめから選ぶ" : "この候補に項目はありませんでした")
                        .font(.handHeadline)
                        .foregroundStyle(Color.inkMain)
                    Text(isSystemSuggestionPickerAvailable
                         ? "タップするとジャーナル候補のピッカーが開きます"
                         : "シミュレータではサンプル候補を表示します")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.inkMain.opacity(0.6))
                }
                Spacer(minLength: 0)
                Text("+")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.appAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color.appAccentPale, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appAccent, lineWidth: 1))
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
