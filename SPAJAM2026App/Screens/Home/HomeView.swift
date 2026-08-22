//
//  HomeView.swift
//  SPAJAM2026App
//
//  起動時のトップ画面。ロゴ(見ざる)+「旅をはじめる」+ 今までの旅のきろく。
//  デザイン: docs/Figma/起動時/旅前_起動時.png
//  過去の旅は永続化未実装のためデモデータ(実装されたら TripSessionStore の履歴に差し替え)。
//

import SwiftUI

struct HomeView: View {
    var onStart: () -> Void

    /// デモ用の過去の旅(デザインのサンプルと同じ)
    private let pastTrips: [(title: String, date: String)] = [
        ("群馬 OB旅行", "2026年8月21日"),
        ("青森 OB旅行", "2026年1月21日"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // ロゴ(仮: 見ざるキャラ。ロゴ素材が来たら差し替え)
            VStack(spacing: 10) {
                Image("MizaruCharacter")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .frame(width: 230, height: 230)
                    .background(.white, in: RoundedRectangle(cornerRadius: 28))
                Text("ミザル")
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.appAccent)
            }
            .frame(maxWidth: .infinity)

            BrushButton(label: "旅をはじめる", action: onStart)
                .padding(.top, 28)

            Spacer()

            Text("今までの旅のきろく")
                .font(.handCaption.bold())
                .foregroundStyle(Color.appAccent)
                .padding(.bottom, 10)

            HStack(spacing: 14) {
                ForEach(pastTrips, id: \.title) { trip in
                    pastTripCard(title: trip.title, date: trip.date)
                }
            }
            .padding(.bottom, 8)
        }
        .padding(24)
        .background(Color.appBackground)
    }

    private func pastTripCard(title: String, date: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.cardStroke)
                    .frame(height: 96)
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.inkSub.opacity(0.5))
            }
            Text(title)
                .font(.handCaption.bold())
                .foregroundStyle(Color.inkMain)
            Text(date)
                .font(.handCaption2)
                .foregroundStyle(Color.inkSub)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(alignment: .topLeading) {
            // マスキングテープ風のアクセント
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.appAccentSoft.opacity(0.55))
                .frame(width: 40, height: 14)
                .rotationEffect(.degrees(-18))
                .offset(x: -8, y: -5)
        }
    }
}

#Preview {
    HomeView(onStart: {})
}
