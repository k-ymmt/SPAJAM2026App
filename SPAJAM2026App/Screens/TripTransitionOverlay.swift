//
//  TripTransitionOverlay.swift
//  SPAJAM2026App
//
//  旅の開始/終了の切り替え演出。フェーズが変わった直後に全画面で 2 秒ほど表示し、
//  ミザル+ひとことで次の画面へつなぐ(唐突な画面切り替えの緩和)。
//

import SwiftUI

enum TripTransition {
    /// 旅をはじめる → 旅行中
    case started
    /// 旅を終える → リザルト
    case finished

    var title: String {
        switch self {
        case .started: "いってらっしゃい!"
        case .finished: "おつかれさま!"
        }
    }

    var subtitle: String {
        switch self {
        case .started: "スマホはおやすみモード。旅をたのしんで"
        case .finished: "旅のきろくをまとめています…"
        }
    }

    /// 表示時間(フェードアウト込み)
    var duration: TimeInterval { 2.0 }
}

struct TripTransitionOverlay: View {
    let transition: TripTransition
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 18) {
            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .frame(width: 170, height: 170)
                .scaleEffect(appeared ? 1.0 : 0.82)
                .rotationEffect(.degrees(appeared ? 0 : -4))

            VStack(spacing: 8) {
                Text(transition.title)
                    .font(.handLargeTitle)
                    .foregroundStyle(Color.appAccent)
                Text(transition.subtitle)
                    .font(.handBody)
                    .foregroundStyle(Color.inkSub)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
                appeared = true
            }
        }
    }
}

#Preview("開始") {
    TripTransitionOverlay(transition: .started)
}

#Preview("終了") {
    TripTransitionOverlay(transition: .finished)
}
