//
//  AreaSelectView.swift
//  SPAJAM2026App
//
//  01 エリア選択。3 ステップでプランを作る:
//  Step1 どこへ(マップにピン) → Step2 だれと(1〜5人) → Step3 温度感(ゆったり/アクティブ/マニア)
//  デザイン: docs/mission-design.pen「01 エリア選択」
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

    var body: some View {
        VStack(spacing: 0) {
            mapArea
            sheet
        }
        .background(Color(red: 0.98, green: 0.965, blue: 0.94))
    }

    // MARK: - マップ

    private var mapArea: some View {
        MapReader { proxy in
            Map(position: $camera) {
                if let pin {
                    Marker("旅先", coordinate: pin)
                        .tint(.orange)
                }
            }
            .onTapGesture { point in
                guard step == 1 else { return }
                if let coordinate = proxy.convert(point, from: .local) {
                    pin = coordinate
                }
            }
            .overlay(alignment: .top) {
                Text(mapHint)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 12)
            }
        }
    }

    private var mapHint: String {
        switch step {
        case 1: pin == nil ? "ピンを置いて旅先を決めよう" : "この辺りの主要スポットで旅をつくります"
        case 2: "だれと行くかを選ぼう"
        default: "旅の温度感を選ぼう"
        }
    }

    // MARK: - 3 ステップシート

    private var sheet: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color(.systemGray4)).frame(width: 44, height: 5)

            stepIndicator

            switch step {
            case 1: stepWhere
            case 2: stepWho
            default: stepMood
            }
        }
        .padding(24)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
        .animation(.default, value: step)
    }

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

    // MARK: Step1 どこへ

    private var stepWhere: some View {
        VStack(spacing: 14) {
            title("どこへ行く?", sub: "マップにピンを置くと、周辺の主要スポットから旅をつくります")

            primaryButton("つぎへ(だれと行く?)", disabled: pin == nil) { step = 2 }

            Button {
                onPlanReady(.bundledDemoPlan())
            } label: {
                Text("デモプラン(浅草)で始める")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Step2 だれと

    private var stepWho: some View {
        VStack(spacing: 14) {
            title("だれと行く?", sub: "いっしょに旅する人数を選んでください")

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    Button {
                        partySize = n
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(n)")
                                .font(.headline)
                            Text(n == 1 ? "ひとり" : "人")
                                .font(.system(size: 9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(partySize == n ? Color.orange : .white, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(partySize == n ? .white : .secondary)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(.systemGray4), lineWidth: partySize == n ? 0 : 1))
                    }
                }
            }

            HStack(spacing: 10) {
                backButton { step = 1 }
                primaryButton("つぎへ(温度感)") { step = 3 }
            }
        }
    }

    // MARK: Step3 温度感

    private var stepMood: some View {
        VStack(spacing: 14) {
            title("旅の温度感は?", sub: "お題の難易度とテイストが変わります")

            HStack(spacing: 8) {
                ForEach(TripMood.allCases) { m in
                    Button {
                        mood = m
                    } label: {
                        Text(m.rawValue)
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(mood == m ? Color.orange : .white, in: Capsule())
                            .foregroundStyle(mood == m ? .white : .secondary)
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: mood == m ? 0 : 1))
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                backButton { step = 2 }
                primaryButton(isGenerating ? "プランを生成中…" : "この旅先でプランをつくる", loading: isGenerating, disabled: isGenerating) {
                    generate()
                }
            }
        }
    }

    // MARK: - 部品

    private func title(_ main: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(main).font(.title3.bold())
            Text(sub).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func primaryButton(_ label: String, loading: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
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

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline)
                .padding(.vertical, 15)
                .padding(.horizontal, 18)
        }
        .buttonStyle(.bordered)
        .disabled(isGenerating)
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
