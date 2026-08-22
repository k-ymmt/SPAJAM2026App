//
//  FirestoreSessionStore.swift
//  SPAJAM2026App
//
//  TripSession のスナップショットを Firestore(sessions/{uid})にも保存する。
//  親と子はそれぞれ自分の uid のドキュメントを持つので、達成状況は別々に管理される。
//  UserDefaults は起動直後の同期復元用ローカルキャッシュとして併用する。
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

/// 招待コード待機中の状態(セッション作成前)。キル後も待機画面に戻れるよう保存する
nonisolated enum PendingJoinStore {
    static let key = "room.pendingJoin"
    nonisolated(unsafe) static var defaults = UserDefaults.standard

    static func save(_ membership: RoomMembership) {
        guard let data = try? JSONEncoder().encode(membership) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> RoomMembership? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RoomMembership.self, from: data)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }
}

final class FirestoreSessionStore: TripSessionRemoteStore, Sendable {
    private func document() -> DocumentReference? {
        guard FirebaseBootstrap.isConfigured, let uid = Auth.auth().currentUser?.uid else { return nil }
        return Firestore.firestore().collection("sessions").document(uid)
    }

    func save(_ snapshot: TripSessionSnapshot) {
        guard let document = document() else { return }
        // シールド選択は端末固有の不透明データなので同期しない
        var remote = snapshot
        remote.shieldSelectionData = nil
        do {
            try document.setData(from: remote)
        } catch {
            NSLog("[Firestore] session save failed: \(error)")
        }
    }

    func clear() {
        document()?.delete()
    }
}
