//
//  MissionCameraView.swift
//  SPAJAM2026App
//
//  04 ミッション実施(判定)。撮影 → 判定パイプライン → 達成/リトライ。
//  デザイン: docs/mission-design.pen「04 ミッション実施(判定)」
//

import CoreLocation
import SwiftUI

struct MissionCameraView: View {
    @Environment(TripSession.self) private var session
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var achievedComment: String?
    @State private var locationProvider = LocationProvider()
    @State private var facing: CameraFacing = .back
    @State private var showMissionList = false
    @State private var showRestrictionAdjust = false

    var body: some View {
        VStack(spacing: 0) {
            if let mission = session.currentMission {
                missionHeader(mission)
                photoArea
                Spacer()
                resultArea
                controls(mission)
            }
        }
        .background(.black)
        .foregroundStyle(.white)
        .sheet(isPresented: $showCamera) {
            switch session.currentMission?.category {
            case .face where FaceSmileCaptureView.isSupported:
                // FACE: AR 笑顔キャプチャ(口角トラッキング可視化つき・対応実機のみ)
                FaceSmileCaptureView { image in
                    capturedImage = image
                }
            case .pose where BodyPoseCaptureView.isSupported:
                // POSE: AR ボディトラッキング(骨格可視化つき・対応実機のみ)
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
            facing = session.currentMission?.camera ?? .back
        }
    }

    private func missionHeader(_ mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MISSION \(mission.order)/\(session.plan.missions.count)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange, in: Capsule())
                Spacer()
                // ミッション一覧へ(一覧から設定=制限調整も開ける)
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

    private var photoArea: some View {
        Group {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.08))
                    .frame(height: 380)
                    .overlay {
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.largeTitle)
                            Text("写真を撮って達成を申請しよう")
                                .font(.footnote)
                        }
                        .foregroundStyle(.white.opacity(0.6))
                    }
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var resultArea: some View {
        if session.isJudging {
            Label("AI が判定中…", systemImage: "sparkles")
                .padding()
        } else if let reason = session.lastFailReason {
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
                showCamera = true
            } label: {
                Label(capturedImage == nil ? "撮影する" : "撮り直す", systemImage: facing == .front ? "person.crop.square.badge.camera" : "camera.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
        .padding(20)
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
