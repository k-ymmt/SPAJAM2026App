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
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
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
                .font(.caption2.bold())
                .foregroundStyle(step >= n ? .white : .secondary)
                .frame(width: 18, height: 18)
                .background(step >= n ? Color.orange : Color(.systemGray5), in: Circle())
            Text(label)
                .font(.caption.weight(step == n ? .bold : .regular))
                .foregroundStyle(step == n ? .primary : .secondary)
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
                            .tint(.orange)
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

            Button {
                onPlanReady(.bundledDemoPlan())
            } label: {
                Text("デモプラン(浅草)で始める")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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
            title("旅の温度感は?", sub: "お題の難易度とテイストが変わります")

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
                    .font(.caption)
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

    /// 中央イラスト。広瀬さんの手書きイラスト素材に差し替える前提のプレースホルダ
    private func illustration(symbol: String, caption: String) -> some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 200, height: 200)
                Image(systemName: symbol)
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
            }
            .contentTransition(.symbolEffect(.replace))
            Text(caption)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .animation(.default, value: symbol)
    }

    private func title(_ main: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(main).font(.title3.bold())
            Text(sub).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selected ? Color.orange : .white, in: Capsule())
                .foregroundStyle(selected ? .white : .secondary)
                .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: selected ? 0 : 1))
        }
    }

    private func nextButton(_ label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if loading { ProgressView().tint(.white) }
                Text(label)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(disabled)
    }

    private func generate() {
        guard let pin else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let plan = try await PlanGenerator().generate(at: pin, partySize: partySize, mood: mood)
                onPlanReady(plan)
            } catch {
                NSLog("[PlanGen] failed: \(error)")
                errorMessage = "生成に失敗しました。もう一度試すか、デモプランで始めてください"
            }
            isGenerating = false
        }
    }
}
