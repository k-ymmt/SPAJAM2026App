//
//  BodyPoseCaptureView.swift
//  SPAJAM2026App
//
//  POSE ミッション用: 2D ボディ検出(frameSemantics = .bodyDetection)で骨格を
//  リアルタイム可視化し、指定ポーズ(万歳 = 両手を頭より上)を 0.8 秒キープしたら自動撮影する。
//  参考: https://qiita.com/1901drama/items/58bce4a1dcea30740678 (Motion Capture 2D)
//  frame.detectedBody の jointLandmarks(正規化画像座標)を displayTransform で
//  ビュー座標へ変換するため、カメラ映像と骨格がズレない。
//

import ARKit
import SwiftUI

struct BodyPoseCaptureView: View {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var joints: [CGPoint] = []
    @State private var bones: [(CGPoint, CGPoint)] = []
    @State private var isPosing = false
    @State private var bodyDetected = false

    static var isSupported: Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.bodyDetection)
    }

    var body: some View {
        ZStack {
            BodyARViewContainer(
                joints: $joints,
                bones: $bones,
                isPosing: $isPosing,
                bodyDetected: $bodyDetected
            ) { image in
                onCapture(image)
                dismiss()
            }
            .ignoresSafeArea()

            // 骨格の可視化(トラッキング中であることを見せる)
            Canvas { context, _ in
                for (a, b) in bones {
                    var path = Path()
                    path.move(to: a)
                    path.addLine(to: b)
                    context.stroke(path, with: .color(.orange.opacity(0.8)), lineWidth: 3)
                }
                for p in joints {
                    let rect = CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: rect), with: .color(isPosing ? .orange : .white))
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                Text("両手を上げて 万歳!")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 24)
                Spacer()
                Text(statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 40)
            }
        }
    }

    private var statusText: String {
        if !bodyDetected { return "カメラに全身を写してください(骨格をトラッキングします)" }
        return isPosing ? "そのポーズキープ!" : "骨格トラッキング中…ポーズをキメて!"
    }
}

private struct BodyARViewContainer: UIViewRepresentable {
    @Binding var joints: [CGPoint]
    @Binding var bones: [(CGPoint, CGPoint)]
    @Binding var isPosing: Bool
    @Binding var bodyDetected: Bool
    var onCapture: (UIImage) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session.delegate = context.coordinator
        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .bodyDetection
        view.session.run(config)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, ARSessionDelegate {
        let parent: BodyARViewContainer
        weak var view: ARSCNView?
        private var poseStartedAt: Date?
        private var captured = false

        // 可視化するジョイントと骨のつながり(2D スケルトン)
        private let jointNames: [ARSkeleton.JointName] = [
            .head, .leftShoulder, .rightShoulder, .leftHand, .rightHand,
            .root, .leftFoot, .rightFoot,
        ]
        private let bonePairs: [(ARSkeleton.JointName, ARSkeleton.JointName)] = [
            (.head, .leftShoulder), (.head, .rightShoulder),
            (.leftShoulder, .leftHand), (.rightShoulder, .rightHand),
            (.leftShoulder, .root), (.rightShoulder, .root),
            (.root, .leftFoot), (.root, .rightFoot),
        ]

        init(parent: BodyARViewContainer) { self.parent = parent }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // 正規化画像座標のままメインへ渡し、変換はメインスレッドで行う
            guard let body = frame.detectedBody else {
                Task { @MainActor in self.parent.bodyDetected = false }
                return
            }
            var landmarks: [ARSkeleton.JointName: CGPoint] = [:]
            for name in jointNames {
                if let l = body.skeleton.landmark(for: name) {
                    landmarks[name] = CGPoint(x: CGFloat(l.x), y: CGFloat(l.y))
                }
            }
            // displayTransform は ARFrame から取る必要があるためここで計算
            let viewSize = MainActor.assumeIsolated { self.view?.bounds.size } ?? .zero
            guard viewSize != .zero else { return }
            let transform = frame.displayTransform(for: .portrait, viewportSize: viewSize)
            let screenPoints: [ARSkeleton.JointName: CGPoint] = landmarks.mapValues { p in
                let normalized = p.applying(transform)
                return CGPoint(x: normalized.x * viewSize.width, y: normalized.y * viewSize.height)
            }
            Task { @MainActor in self.handle(screenPoints: screenPoints) }
        }

        private func handle(screenPoints: [ARSkeleton.JointName: CGPoint]) {
            guard !captured else { return }
            parent.bodyDetected = !screenPoints.isEmpty

            parent.joints = Array(screenPoints.values)
            parent.bones = bonePairs.compactMap { a, b in
                guard let pa = screenPoints[a], let pb = screenPoints[b] else { return nil }
                return (pa, pb)
            }

            // 万歳判定: 画面座標で両手が頭より上(y が小さい)
            guard let head = screenPoints[.head],
                  let lh = screenPoints[.leftHand],
                  let rh = screenPoints[.rightHand] else {
                parent.isPosing = false
                poseStartedAt = nil
                return
            }
            let posing = lh.y < head.y && rh.y < head.y
            parent.isPosing = posing

            if posing {
                if poseStartedAt == nil { poseStartedAt = Date() }
                if let start = poseStartedAt, Date().timeIntervalSince(start) > 0.8 {
                    captured = true
                    captureFrame()
                }
            } else {
                poseStartedAt = nil
            }
        }

        private func captureFrame() {
            guard let frame = view?.session.currentFrame else { return }
            let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let ciContext = CIContext()
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
            parent.onCapture(image)
        }
    }
}
