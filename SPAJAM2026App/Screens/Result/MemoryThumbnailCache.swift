//
//  MemoryThumbnailCache.swift
//  SPAJAM2026App
//
//  思い出カルーセル用の縮小済みサムネイル。フル解像度の写真をスクロール中に毎回読み直すとカクつくため、
//  表示サイズに縮小・事前デコードした UIImage を項目 id ごとに 1 回だけ作って持つ。
//

import UIKit

@MainActor
@Observable
final class MemoryThumbnailCache {
    /// サムネイルの元
    enum Source {
        /// ローカルファイル(Documents 配下の写真)
        case file(URL)
        /// 既にメモリにある画像(Storage から取得した他の参加者の写真)
        case image(UIImage)
    }

    /// 項目 id → サムネイル
    private(set) var images: [String: UIImage] = [:]
    private var inFlight: Set<String> = []

    func image(for entryId: String) -> UIImage? { images[entryId] }

    /// まだ無い項目のサムネイルをバックグラウンドで作る。`pixelSize` は表示サイズ × 画面スケール
    func prepare(_ sources: [(id: String, source: Source)], pixelSize: CGSize) {
        for (id, source) in sources where images[id] == nil && !inFlight.contains(id) {
            inFlight.insert(id)
            Task {
                let thumbnail = await Self.makeThumbnail(source, pixelSize: pixelSize)
                inFlight.remove(id)
                if let thumbnail { images[id] = thumbnail }
            }
        }
    }

    nonisolated private static func makeThumbnail(_ source: Source, pixelSize: CGSize) async -> UIImage? {
        let original: UIImage? = switch source {
        case .file(let url): UIImage(contentsOfFile: url.path)
        case .image(let image): image
        }
        guard let original else { return nil }
        // 短辺をサムネイルに合わせて縮小(scaledToFill 相当の見え方になるよう、はみ出す分は表示側で clip)
        let scale = max(pixelSize.width / max(original.size.width, 1), pixelSize.height / max(original.size.height, 1))
        let size = CGSize(width: original.size.width * min(1, scale), height: original.size.height * min(1, scale))
        return await original.byPreparingThumbnail(ofSize: size) ?? original
    }
}
