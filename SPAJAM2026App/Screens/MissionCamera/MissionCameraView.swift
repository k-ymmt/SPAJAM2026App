//
//  MissionCameraView.swift
//  SPAJAM2026App
//
//  04 ミッション実施(判定)。横スワイプでミッションを切り替え、
//  location 系はマップをメイン表示 → 撮影ボタン → 「判定しますか?」→ 判定。
//  カメラ反転は標準カメラ UI 内のボタンを使う。
//  デザイン: docs/mission-design.pen「04 ミッション実施(判定)」
//

import CoreLocation
import MapKit
import SwiftUI

struct MissionCameraView: View {
    @Environment(TripSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var useLibrary = false
    @State private var facing: CameraFacing = .back
    @State private var selectedMissionId: String = ""
    /// 撮影/取り込み直後の「判定しますか?」確認
    @State private var showJudgeConfirm = false

    var body: some View {
        // 横スワイプでミッションを切り替えるページャー
        TabView(selection: $selectedMissionId) {
            ForEach(session.plan.missions) { mission in
                missionPage(mission)
                    .tag(mission.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(.black)
        .foregroundStyle(.white)
        .sheet(isPresented: $showCamera) {
            switch session.currentMission?.category {
            case .face where FaceSmileCaptureView.isSupported:
                FaceSmileCaptureView { image in
                    capturedImage = image
                    showJudgeConfirm = true
                }
            case .pose where BodyPoseCaptureView.isSupported:
                BodyPoseCaptureView { image in
                    capturedImage = image
                    showJudgeConfirm = true
                }
            default:
                CameraPicker(facing: facing, useLibrary: useLibrary) { image in
                    capturedImage = image
                    showJudgeConfirm = true
                }
                .ignoresSafeArea()
            }
        }
        .confirmationDialog(
            "この写真で判定しますか?",
            isPresented: $showJudgeConfirm,
            titleVisibility: .visible
        ) {
            Button("判定する") { judge() }
            Button("撮り直す") {
                capturedImage = nil
                useLibrary = false
                showCamera = true
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            selectedMissionId = session.currentMission?.id ?? session.plan.missions.first?.id ?? ""
            facing = session.currentMission?.camera ?? .back
        }
        // スワイプでページが変わったら挑戦対象を切り替え
        .onChange(of: selectedMissionId) { _, newId in
            if let mission = session.plan.missions.first(where: { $0.id == newId }) {
                session.selectMission(mission)
                capturedImage = nil
                facing = mission.camera ?? .back
            }
        }
        // 一覧などから挑戦対象が変わったらページを追従
        .onChange(of: session.currentMission?.id) { _, newId in
            if let newId, newId != selectedMissionId {
                selectedMissionId = newId
                capturedImage = nil
                facing = session.currentMission?.camera ?? .back
            }
        }
    }

    // MARK: - 1 ミッション分のページ

    @ViewBuilder
    private func missionPage(_ mission: Mission) -> some View {
        let achieved = session.isAchieved(mission)
        let record = session.records.first { $0.missionId == mission.id }

        VStack(spacing: 0) {
            missionHeader(mission, achieved: achieved)
            photoArea(mission, achieved: achieved, record: record)
            Spacer()
            resultArea(mission, achieved: achieved)
            if !achieved {
                controls(mission)
            } else {
                achievedFooter(record)
            }
        }
    }

    private func missionHeader(_ mission: Mission, achieved: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MISSION \(mission.order)/\(session.plan.missions.count)")
                    .font(.handCaption2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(achieved ? Color.appAccentSoft : Color.appAccent, in: Capsule())
                if achieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                }
                Spacer()
                // ミッション一覧(メイン画面)へ戻る
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.handHeadline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.2), in: Circle())
                }
            }
            Text(mission.title)
                .font(.handTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle(for: mission))
                .font(.handCaption)
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
    }

    /// タイトル下の補足説明(カテゴリ別)
    private func subtitle(for mission: Mission) -> String {
        let place = mission.judgment.location?.name
        return switch mission.category {
        case .go: "\(place ?? "目的地")へ向かおう。着いたら写真を撮って判定!"
        case .do: place.map { "\($0)でお題を見つけて撮影しよう" } ?? "現地でお題を見つけて撮影しよう"
        case .eat: "食べる前にパシャリ。おいしさが伝わる一枚を"
        case .face: "インカメラで表情をつくって撮影しよう"
        case .pose: "ポーズ全体が写るように撮ろう"
        case .buy: "買ったものがわかるように撮影しよう"
        case .find: "見つけたら逃さず撮影しよう"
        }
    }

    /// メイン表示エリア。location 系はマップ、撮影後は写真プレビュー(タップで撮り直し)
    @ViewBuilder
    private func photoArea(_ mission: Mission, achieved: Bool, record: MissionRecord?) -> some View {
        Group {
            if achieved {
                // 達成済み: 記録写真を表示(タップ不可)
                if let record, let image = session.photo(for: record) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    placeholder(icon: "checkmark.circle", text: "達成済みのミッションです")
                }
            } else if let image = capturedImage, mission.id == selectedMissionId {
                Button {
                    useLibrary = false
                    showCamera = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 380)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(alignment: .bottomTrailing) {
                            Label("タップで撮り直し", systemImage: "camera.fill")
                                .font(.handCaption2)
                                .padding(8)
                                .background(.black.opacity(0.6), in: Capsule())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            } else if let target = mission.judgment.location {
                // location 系: 目的地マップをメイン表示
                missionMap(target)
            } else {
                Button {
                    useLibrary = false
                    showCamera = true
                } label: {
                    if [.eat, .buy, .find].contains(mission.category) {
                        mizaruPlaceholder(text: "下の撮影ボタンでスタート")
                    } else {
                        placeholder(icon: "camera.fill", text: "下の撮影ボタンでスタート")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    /// EAT / BUY / FIND 用: ミザルが待っているプレースホルダ
    private func mizaruPlaceholder(text: String) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white.opacity(0.08))
            .frame(height: 380)
            .overlay {
                VStack(spacing: 14) {
                    Image("MizaruCharacter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190, height: 190)
                    Text(text)
                        .font(.handBody)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
    }

    /// 目的地ピン+現在地のマップ
    private func missionMap(_ target: GeoTarget) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: target.latitude, longitude: target.longitude)
        return Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 900, longitudinalMeters: 900
        ))) {
            Marker(target.name ?? "目的地", coordinate: coordinate)
                .tint(Color.appAccent)
            UserAnnotation()
        }
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func placeholder(icon: String, text: String) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white.opacity(0.08))
            .frame(height: 380)
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.largeTitle)
                    Text(text)
                        .font(.handBody)
                }
                .foregroundStyle(.white.opacity(0.6))
            }
    }

    @ViewBuilder
    private func resultArea(_ mission: Mission, achieved: Bool) -> some View {
        if session.isJudging, mission.id == selectedMissionId {
            Label("AI が判定中…", systemImage: "sparkles")
                .padding()
        } else if let reason = session.lastFailReason, mission.id == selectedMissionId {
            Label(reason, systemImage: "xmark.circle.fill")
                .font(.handBody)
                .padding(12)
                .background(.red.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
        }
    }

    private func controls(_ mission: Mission) -> some View {
        HStack(spacing: 12) {
            // 撮影(メイン)。撮影済みなら再判定の導線に
            Button {
                if capturedImage != nil {
                    showJudgeConfirm = true
                } else {
                    useLibrary = false
                    showCamera = true
                }
            } label: {
                Label(
                    capturedImage != nil ? "この写真で判定する" : "撮影する",
                    systemImage: capturedImage != nil ? "sparkles" : "camera.fill"
                )
                .font(.handHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
            .disabled(session.isJudging)

            // 撮影済みのときは撮り直しボタンを出す
            if capturedImage != nil {
                Button {
                    capturedImage = nil
                    useLibrary = false
                    showCamera = true
                } label: {
                    Image(systemName: "camera.fill")
                        .padding(14)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .disabled(session.isJudging)
            }

            // 予備: カメラロールから取り込み(端に配置)
            Button {
                useLibrary = true
                showCamera = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .padding(14)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .disabled(session.isJudging)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
    }

    /// 判定を実行し、達成したら一覧へ戻る
    private func judge() {
        Task {
            let ok = await session.judgeCurrentMission(
                image: capturedImage,
                location: session.locationProvider.current
            )
            if ok {
                capturedImage = nil
                // 達成したらメイン(ミッション一覧)へ戻る
                dismiss()
            }
        }
    }

    private func achievedFooter(_ record: MissionRecord?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.teal)
            Text("達成! +\(record?.points ?? 0)pt")
                .font(.handHeadline)
            if let comment = record?.aiComment {
                Text(comment)
                    .font(.handCaption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
    }
}

/// 現在地の簡易プロバイダ。位置更新は onUpdate 経由で TripSession(接近判定・LA 更新)にも流す
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var current: CLLocation?
    var onUpdate: ((CLLocation) -> Void)?

    func start() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.current = latest
            self.onUpdate?(latest)
        }
    }
}
