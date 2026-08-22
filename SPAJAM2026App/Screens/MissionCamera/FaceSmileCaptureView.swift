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
    @State private var smileLevel: Double = 0

    static var isSupported: Bool { ARFaceTrackingConfiguration.isSupported }

    var body: some View {
        ZStack {
            FaceARViewContainer(smileLevel: $smileLevel) { image in
                onCapture(image)
                dismiss()
            }
            .ignoresSafeArea()

            VStack {
                Text("にっこり笑って!")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 24)
                Spacer()
                // 笑顔メーター
                VStack(spacing: 8) {
                    ProgressView(value: smileLevel)
                        .tint(.orange)
                        .frame(width: 220)
                    Text(smileLevel > 0.5 ? "その笑顔キープ!" : "笑顔メーター")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
                .padding(16)
                .background(.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 40)
            }
        }
    }
}

private struct FaceARViewContainer: UIViewRepresentable {
    @Binding var smileLevel: Double
    var onCapture: (UIImage) -> Void

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session.delegate = context.coordinator
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

    final class Coordinator: NSObject, ARSessionDelegate {
        let parent: FaceARViewContainer
        weak var view: ARSCNView?
        private var smileStartedAt: Date?
        private var captured = false

        init(parent: FaceARViewContainer) { self.parent = parent }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            guard let face = anchors.compactMap({ $0 as? ARFaceAnchor }).first else { return }
            let left = face.blendShapes[.mouthSmileLeft]?.doubleValue ?? 0
            let right = face.blendShapes[.mouthSmileRight]?.doubleValue ?? 0
            let level = (left + right) / 2
            Task { @MainActor in self.handle(level: level) }
        }

        private func handle(level: Double) {
            guard !captured else { return }
            parent.smileLevel = level
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
