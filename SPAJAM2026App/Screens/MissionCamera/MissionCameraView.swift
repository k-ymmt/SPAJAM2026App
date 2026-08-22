//
//  MissionCameraView.swift
//  SPAJAM2026App
//
//  04 ミッション実施(判定)。横スワイプでミッションを切り替え、
//  写真エリアをタップして撮影 → 判定パイプライン → 達成/リトライ。
//  デザイン: docs/mission-design.pen「04 ミッション実施(判定)」
//

import CoreLocation
import SwiftUI

struct MissionCameraView: View {
    @Environment(TripSession.self) private var session
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var locationProvider = LocationProvider()
    @State private var facing: CameraFacing = .back
    @State private var showMissionList = false
    @State private var showRestrictionAdjust = false
    @State private var selectedMissionId: String = ""

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
                }
            case .pose where BodyPoseCaptureView.isSupported:
                BodyPoseCaptureView { image in
                    capturedImage = image
                }
            default:
                CameraPicker(facing: facing) { image in
                    capturedImage = image
                }
                .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showMissionList) {
            TripMissionListView {
                showRestrictionAdjust = true
            }
            .environment(session)
        }
        .sheet(isPresented: $showRestrictionAdjust) {
            RestrictionAdjustView()
                .environment(session)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            locationProvider.start()
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
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(achieved ? .teal : .orange, in: Capsule())
                if achieved {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.teal)
                }
                Spacer()
                Button {
                    showMissionList = true
                } label: {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.white.opacity(0.2), in: Circle())
                }
            }
            Text(mission.title)
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
    }

    /// 写真エリア。タップで撮影(撮り直しもタップ)
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
            } else {
                Button {
                    showCamera = true
                } label: {
                    if let image = capturedImage, mission.id == selectedMissionId {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(alignment: .bottomTrailing) {
                                Label("タップで撮り直し", systemImage: "camera.fill")
                                    .font(.caption2)
                                    .padding(8)
                                    .background(.black.opacity(0.6), in: Capsule())
                                    .padding(8)
                            }
                    } else {
                        placeholder(icon: "camera.fill", text: "タップして撮影しよう")
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
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
                        .font(.footnote)
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
                .font(.footnote)
                .padding(12)
                .background(.red.opacity(0.25), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
        }
    }

    private func controls(_ mission: Mission) -> some View {
        HStack(spacing: 12) {
            // イン/アウトカメラ切り替え
            Button {
                facing = facing == .back ? .front : .back
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.camera.fill")
                    .padding(14)
            }
            .buttonStyle(.bordered)
            .tint(.white)

            Button {
                Task {
                    let ok = await session.judgeCurrentMission(
                        image: capturedImage,
                        location: locationProvider.current
                    )
                    if ok { capturedImage = nil }
                }
            } label: {
                Text("判定する")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(capturedImage == nil || session.isJudging)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
    }

    private func achievedFooter(_ record: MissionRecord?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.teal)
            Text("達成! +\(record?.points ?? 0)pt")
                .font(.subheadline.bold())
            if let comment = record?.aiComment {
                Text(comment)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 36)
    }
}

/// 現在地の簡易プロバイダ(P0: その場取得のみ。ジオフェンス接近通知は P1)
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var current: CLLocation?

    func start() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in self.current = latest }
    }
}
