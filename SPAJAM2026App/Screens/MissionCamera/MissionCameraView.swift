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
            // FACE ミッションは AR 笑顔キャプチャ(対応実機のみ)、それ以外は通常カメラ
            if session.currentMission?.category == .face, FaceSmileCaptureView.isSupported {
                FaceSmileCaptureView { image in
                    capturedImage = image
                }
            } else {
                CameraPicker(facing: session.currentMission?.camera ?? .back) { image in
                    capturedImage = image
                }
                .ignoresSafeArea()
            }
        }
        .onAppear { locationProvider.start() }
    }

    private func missionHeader(_ mission: Mission) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MISSION \(mission.order)/\(session.plan.missions.count)")
                .font(.caption2.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.orange, in: Capsule())
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
            Button {
                showCamera = true
            } label: {
                Label(capturedImage == nil ? "撮影する" : "撮り直す", systemImage: "camera.fill")
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
