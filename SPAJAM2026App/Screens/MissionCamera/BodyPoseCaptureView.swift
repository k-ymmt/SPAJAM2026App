//
//  BodyPoseCaptureView.swift
//  SPAJAM2026App
//
//  POSE ミッション用: ARKit Body Tracking で骨格をリアルタイム可視化し、
//  指定ポーズ(万歳 = 両手を頭より上)を 0.8 秒キープしたら自動撮影する。
//  撮影後は通常の判定パイプラインに合流する。対応実機(A12 以降・背面カメラ)専用。
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

    static var isSupported: Bool { ARBodyTrackingConfiguration.isSupported }

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
        let config = ARBodyTrackingConfiguration()
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

        // 可視化する主要ジョイントと骨のつながり
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

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let body = anchors.compactMap({ $0 as? ARBodyAnchor }).first else { return }
            Task { @MainActor in self.handle(body: body) }
        }

        private func handle(body: ARBodyAnchor) {
            guard !captured, let view else { return }
            parent.bodyDetected = true

            // ジョイントのワールド座標
            func worldPosition(_ name: ARSkeleton.JointName) -> simd_float4x4? {
                guard let t = body.skeleton.modelTransform(for: name) else { return nil }
                return body.transform * t
            }
            func screenPoint(_ name: ARSkeleton.JointName) -> CGPoint? {
                guard let m = worldPosition(name) else { return nil }
                let pos = SCNVector3(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                let projected = view.projectPoint(pos)
                guard projected.z > 0 else { return nil }
                return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
            }

            // 骨格の可視化データを更新
            var points: [CGPoint] = []
            var lines: [(CGPoint, CGPoint)] = []
            var screenCache: [ARSkeleton.JointName: CGPoint] = [:]
            for name in jointNames {
                if let p = screenPoint(name) {
                    screenCache[name] = p
                    points.append(p)
                }
            }
            for (a, b) in bonePairs {
                if let pa = screenCache[a], let pb = screenCache[b] {
                    lines.append((pa, pb))
                }
            }
            parent.joints = points
            parent.bones = lines

            // 万歳判定: 両手のワールド Y が頭より上
            guard let head = worldPosition(.head),
                  let lh = worldPosition(.leftHand),
                  let rh = worldPosition(.rightHand) else { return }
            let posing = lh.columns.3.y > head.columns.3.y && rh.columns.3.y > head.columns.3.y
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
