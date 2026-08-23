//
//  MomentPhotoStore.swift
//  SPAJAM2026App
//
//  Firebase Storage にある他の参加者の「心が動いた瞬間」の写真をダウンロードして持つ。
//  メモリ + Caches ディレクトリに保存し、同じ写真は 1 回しか取りに行かない。
//

import FirebaseStorage
import Foundation
import UIKit

@MainActor
@Observable
final class MomentPhotoStore {
    /// storagePath → 画像
    private(set) var images: [String: UIImage] = [:]
    private var inFlight: Set<String> = []

    /// 1 枚の上限(アップロード側は 1MB 未満に縮小している)
    private static let maxBytes: Int64 = 4 * 1024 * 1024

    func image(for moment: SharedHeartMoment) -> UIImage? {
        images[moment.storagePath]
    }

    /// まだ持っていない写真を取りに行く(キャッシュにあればそこから)
    func load(_ moments: [SharedHeartMoment]) {
        for moment in moments where images[moment.storagePath] == nil && !inFlight.contains(moment.storagePath) {
            inFlight.insert(moment.storagePath)
            let path = moment.storagePath
            if let cached = UIImage(contentsOfFile: Self.cacheURL(for: path).path) {
                images[path] = cached
                inFlight.remove(path)
                continue
            }
            Task {
                defer { inFlight.remove(path) }
                guard FirebaseBootstrap.isConfigured else { return }
                do {
                    let data = try await Storage.storage().reference(withPath: path).data(maxSize: Self.maxBytes)
                    guard let image = UIImage(data: data) else { return }
                    images[path] = image
                    try? data.write(to: Self.cacheURL(for: path))
                } catch {
                    print("moment photo download failed: \(error)")
                }
            }
        }
    }

    private static func cacheURL(for storagePath: String) -> URL {
        let dir = URL.cachesDirectory.appending(path: "moments")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = storagePath.replacingOccurrences(of: "/", with: "_")
        return dir.appending(path: name)
    }
}
