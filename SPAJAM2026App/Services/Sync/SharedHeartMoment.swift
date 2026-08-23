//
//  SharedHeartMoment.swift
//  SPAJAM2026App
//
//  ルームに共有された「心が動いた瞬間」の写真 1 枚分のメタデータ。
//  写真本体は Firebase Storage(`storagePath`)、メタデータは Firestore: rooms/{code}/moments/{id}
//

import Foundation

nonisolated struct SharedHeartMoment: Codable, Sendable, Identifiable, Equatable {
    /// HeartMoment.id と同じ
    var id: String
    /// 撮った人の uid
    var uid: String
    /// 撮った人の表示名
    var name: String
    var capturedAt: Date
    var bpm: Int?
    /// Firebase Storage のパス(rooms/{code}/moments/{uid}/{id}.jpg)
    var storagePath: String

    static func storagePath(code: String, uid: String, momentId: String) -> String {
        "rooms/\(code)/moments/\(uid)/\(momentId).jpg"
    }
}
