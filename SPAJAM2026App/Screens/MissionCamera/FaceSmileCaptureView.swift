//
//  FaceSmileCaptureView.swift
//  SPAJAM2026App
//
//  FACE ミッション用: ARKit Face Tracking(TrueDepth)で笑顔をリアルタイム判定し、
//  笑顔が続いた瞬間のフレームを自動撮影する。撮影後は通常の判定パイプラインに合流する。
//  実機(TrueDepth 搭載)専用。非対応環境では呼び出し側がカメラ/ライブラリにフォールバック。
//

import ARKit
import SwiftUI

struct FaceSmileCaptureView: View {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var smileLeft: Double = 0
    @State private var smileRight: Double = 0

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    private var smileLevel: Double { (smileLeft + smileRight) / 2 }

    var body: some View {
        ZStack {
            FaceARViewContainer(smileLeft: $smileLeft, smileRight: $smileRight) { image in
                onCapture(image)
                dismiss()
            }
            .ignoresSafeArea()

            VStack {
                Text("にっこり笑って!")
                    .font(.handTitle)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 24)
                Spacer()
                // 口角トラッキングの可視化(左右それぞれの上がり具合を表示)
                VStack(spacing: 10) {
                    HStack(spacing: 16) {
                        cornerGauge(label: "左の口角", value: smileLeft)
                        cornerGauge(label: "右の口角", value: smileRight)
                    }
                    ProgressView(value: min(1, smileLevel))
                        .tint(.orange)
                        .frame(width: 240)
                    Text(smileLevel > 0.5 ? "その笑顔キープ!" : "口角をトラッキング中…")
                        .font(.handCaption)
                        .foregroundStyle(.white)
                }
                .padding(16)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 40)
            }
        }
    }

    private func cornerGauge(label: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text("\(Int(min(1, value) * 100))%")
                .font(.handHeadline)
                .foregroundStyle(value > 0.5 ? .orange : .white)
            Text(label)
                .font(.handCaption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(width: 90)
    }
}

private struct FaceARViewContainer: UIViewRepresentable {
    @Binding var smileLeft: Double
    @Binding var smileRight: Double
    var onCapture: (UIImage) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session.delegate = context.coordinator
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        let config = ARFaceTrackingConfiguration()
        view.session.run(config)
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        let parent: FaceARViewContainer
        weak var view: ARSCNView?
        private var smileStartedAt: Date?
        private var captured = false

        init(parent: FaceARViewContainer) { self.parent = parent }

        // 顔メッシュをワイヤーフレームで重ねて「トラッキングしている」ことを可視化する
        nonisolated func renderer(_ renderer: any SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard anchor is ARFaceAnchor,
                  let device = (renderer as? ARSCNView)?.device,
                  let geometry = ARSCNFaceGeometry(device: device) else { return nil }
            let material = geometry.firstMaterial
            material?.diffuse.contents = UIColor.systemOrange.withAlphaComponent(0.55)
            material?.fillMode = .lines
            let node = SCNNode(geometry: geometry)
            return node
        }

        nonisolated func renderer(_ renderer: any SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let faceAnchor = anchor as? ARFaceAnchor,
                  let geometry = node.geometry as? ARSCNFaceGeometry else { return }
            geometry.update(from: faceAnchor.geometry)
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            let left = face.blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
            let right = face.blendShapes[.mouthSmileRight]?.doubleValue ?? 0
            Task { @MainActor in self.handle(left: left, right: right) }
        }

        private func handle(left: Double, right: Double) {
            guard !captured else { return }
            parent.smileLeft = left
            parent.smileRight = right
            let level = (left + right) / 2
            if level > 0.5 {
                if smileStartedAt == nil { smileStartedAt = Date() }
                // 0.8 秒笑顔をキープしたら自動撮影
                if let start = smileStartedAt, Date().timeIntervalSince(start) > 0.8 {
                    captured = true
                    captureFrame()
                }
            } else {
                smileStartedAt = nil
            }
        }

        private func captureFrame() {
            guard let frame = view?.session.currentFrame else { return }
            let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
            let ciContext = CIContext()
            guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }
            // フロントカメラのフレームは横向きで届くため縦位置に回転
            let image = UIImage(cgImage: cgImage, scale: 1, orientation: .leftMirrored)
            parent.onCapture(image)
        }
    }
}
