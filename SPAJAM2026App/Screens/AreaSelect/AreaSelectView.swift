//
//  AreaSelectView.swift
//  SPAJAM2026App
//
//  01 エリア選択。3 ステップがスライドで切り替わる:
//  Step1 どこへ(マップにピン) → Step2 だれと(1〜5人) → Step3 温度感(ゆったり/アクティブ/マニア)
//  中央のイラストはステップと選択に応じて変わる(手書きイラスト素材に差し替え予定)。
//  ボタンは「つぎへ」のみ(戻るなし)。
//

import CoreLocation
import MapKit
import SwiftUI

struct AreaSelectView: View {
    var onPlanReady: (TravelPlan) -> Void

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671), // 東京駅
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @State private var step = 1
    @State private var pin: CLLocationCoordinate2D?
    @State private var partySize = 2
    @State private var mood: TripMood = .relaxed
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private let slide: AnyTransition = .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )

    var body: some View {
        VStack(spacing: 20) {
            stepIndicator
                .padding(.top, 12)

            ZStack {
                switch step {
                case 1: slideWhere.transition(slide)
                case 2: slideWho.transition(slide)
                default: slideMood.transition(slide)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: step)
        }
        .padding(24)
        .background(Color.appBackground)
    }

    // MARK: - ステップインジケータ

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            stepChip(1, "どこへ")
            stepChip(2, "だれと")
            stepChip(3, "温度感")
            Spacer()
        }
    }

    private func stepChip(_ n: Int, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text("\(n)")
                .font(.handCaption2)
                .foregroundStyle(step >= n ? .white : .secondary)
                .frame(width: 18, height: 18)
                .background(step >= n ? Color.appAccent : Color(.systemGray5), in: Circle())
            Text(label)
                .font(.handCaption)
                .foregroundStyle(step == n ? Color.inkMain : Color.inkSub)
        }
    }

    // MARK: - Step1 どこへ(マップが主役)

    private var slideWhere: some View {
        VStack(spacing: 16) {
            title("どこへ行く?", sub: "マップにピンを置くと、周辺の主要スポットから旅をつくります")

            MapReader { proxy in
                Map(position: $camera) {
                    if let pin {
                        Marker("旅先", coordinate: pin)
                            .tint(Color.appAccent)
                    }
                }
                .onTapGesture { point in
                    if let coordinate = proxy.convert(point, from: .local) {
                        pin = coordinate
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))

            nextButton("つぎへ", disabled: pin == nil) { step = 2 }
        }
    }

    // MARK: - Step2 だれと(イラストが人数で変わる)

    private var slideWho: some View {
        VStack(spacing: 16) {
            title("だれと行く?", sub: "いっしょに旅する人数を選んでください")

            Spacer()
            illustration(symbol: partySymbol, caption: partySize == 1 ? "ひとり旅" : "\(partySize)人旅")
            Spacer()

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    selectChip("\(n)", selected: partySize == n) { partySize = n }
                }
            }

            nextButton("つぎへ") { step = 3 }
        }
    }

    private var partySymbol: String {
        switch partySize {
        case 1: "figure.walk"
        case 2: "figure.2"
        default: "figure.2.and.child.holdinghands"
        }
    }

    // MARK: - Step3 温度感(イラストが温度感で変わる)

    private var slideMood: some View {
        VStack(spacing: 16) {
            title("旅の温度感は?", sub: "ミッションの難易度とテイストが変わります")

            Spacer()
            illustration(symbol: moodSymbol, caption: mood.rawValue)
            Spacer()

            HStack(spacing: 8) {
                ForEach(TripMood.allCases) { m in
                    selectChip(m.rawValue, selected: mood == m) { mood = m }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.handCaption)
                    .foregroundStyle(.red)
            }

            nextButton(isGenerating ? "プランを生成中…" : "この旅先でプランをつくる", loading: isGenerating, disabled: isGenerating) {
                generate()
            }
        }
    }

    private var moodSymbol: String {
        switch mood {
        case .relaxed: "cup.and.saucer.fill"
        case .active: "figure.run"
        case .mania: "binoculars.fill"
        }
    }

    // MARK: - 部品

    /// 中央イラスト。見ざるキャラ(広瀬さんの差し替え素材が来たらステップごとに切り替える)
    private func illustration(symbol: String, caption: String) -> some View {
        VStack(spacing: 14) {
            Image("MizaruCharacter")
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(width: 210, height: 210)
                .background(.white, in: RoundedRectangle(cornerRadius: 24))
            Text(caption)
                .font(.handHeadline)
                .foregroundStyle(Color.appAccent)
        }
        .animation(.default, value: symbol)
    }

    private func title(_ main: String, sub: String) -> some View {
        ScreenHeader(main, subtitle: sub)
    }

    private func selectChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.handBody)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.appAccent : .white, in: Capsule())
                .foregroundStyle(selected ? .white : Color.inkSub)
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: selected ? 0 : 1))
        }
    }

    private func nextButton(_ label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        BrushButton(label: label, loading: loading, disabled: disabled, action: action)
    }

    private func generate() {
        guard let pin else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let plan = try await PlanGenerator().generate(at: pin, partySize: partySize, mood: mood)
                onPlanReady(plan)
            } catch PlanGenerator.GenError.timeout {
                NSLog("[PlanGen] timed out")
                errorMessage = "生成がタイムアウトしました。電波の良い場所でもう一度お試しください"
            } catch PlanGenerator.GenError.noKey {
                errorMessage = "API キー(Secrets.plist)が設定されていません"
            } catch {
                NSLog("[PlanGen] failed: \(error)")
                errorMessage = "生成に失敗しました。もう一度お試しください"
            }
            isGenerating = false
        }
    }
}
