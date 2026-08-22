//
//  AreaSelectView.swift
//  SPAJAM2026App
//
//  01 エリア選択。マップにピン → 主要地スナップ → プラン生成。
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
    @State private var pin: CLLocationCoordinate2D?
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

    private var mapArea: some View {
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
            .overlay(alignment: .top) {
                Text(pin == nil ? "ピンを置いて旅先を決めよう" : "この辺りの主要スポットで旅をつくります")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 12)
            }
        }
    }

    private var sheet: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color(.systemGray4)).frame(width: 44, height: 5)

            VStack(alignment: .leading, spacing: 6) {
                Text("旅をつくる")
                    .font(.title3.bold())
                Text("ピンの位置から主要エリアを推定して、5つのミッションを自動生成します")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(TripMood.allCases) { m in
                    Button {
                        mood = m
                    } label: {
                        Text(m.rawValue)
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(mood == m ? Color.orange : .white, in: Capsule())
                            .foregroundStyle(mood == m ? .white : .secondary)
                            .overlay(Capsule().stroke(Color(.systemGray4), lineWidth: mood == m ? 0 : 1))
                    }
                }
                Spacer()
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                generate()
            } label: {
                Group {
                    if isGenerating {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("プランを生成中…")
                        }
                    } else {
                        Text("この旅先でプランをつくる")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(pin == nil || isGenerating)

            Button {
                onPlanReady(.bundledDemoPlan())
            } label: {
                Text("デモプラン(浅草)で始める")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .disabled(isGenerating)
        }
        .padding(24)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }

    private func generate() {
        guard let pin else { return }
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let plan = try await PlanGenerator().generate(at: pin, mood: mood)
                onPlanReady(plan)
            } catch {
                NSLog("[PlanGen] failed: \(error)")
                errorMessage = "生成に失敗しました。もう一度試すか、デモプランで始めてください"
            }
            isGenerating = false
        }
    }
}
