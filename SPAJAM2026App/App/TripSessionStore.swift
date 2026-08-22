//
//  TripSessionStore.swift
//  SPAJAM2026App
//
//  TripSession の進行状態をキル後も復元できるようにスナップショットとして保存する。
//  UserDefaults に JSON で書き込み、起動時に読み戻す。
//

import Foundation

/// TripSession の永続化対象。Phase やシールド選択など、メモリ上の状態を Codable に写したもの
nonisolated struct TripSessionSnapshot: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable {
        case planning, restrictionSetup, traveling, finished
    }

    var plan: TravelPlan
    var phase: Phase
    var currentMissionId: String?
    var records: [MissionRecord]
    var heartRateSamples: [HeartRateSample]
    var useMockJudge: Bool
    var tripStartedAt: Date?
    var tripEndedAt: Date?
    var foregroundSeconds: TimeInterval
    /// 保存時点でアプリが前面だった場合、その開始時刻。復元時に savedAt までを前面時間として確定する
    var becameActiveAt: Date?
    var restrictionAdjustments: Int
    /// FamilyActivitySelection を JSON エンコードしたもの(FamilyControls が無い環境では nil)
    var shieldSelectionData: Data?
    var savedAt: Date
    /// 複数人の旅なら、自分のルームと役割(親/子)
    var membership: RoomMembership? = nil
}

/// スナップショットのリモート保存先(Firestore など)。テストでは nil のまま
nonisolated protocol TripSessionRemoteStore: Sendable {
    func save(_ snapshot: TripSessionSnapshot)
    func clear()
}

/// スナップショットの保存先。テストでは `defaults` を差し替える
nonisolated enum TripSessionStore {
    static let key = "tripSession.snapshot"
    nonisolated(unsafe) static var defaults = UserDefaults.standard
    /// Firebase 構成時に FirestoreSessionStore が入る。UserDefaults と併せて二重に保存する
    nonisolated(unsafe) static var remote: (any TripSessionRemoteStore)?

    static func save(_ snapshot: TripSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
        remote?.save(snapshot)
    }

    static func load() -> TripSessionSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(TripSessionSnapshot.self, from: data)
    }

    static func clear() {
        defaults.removeObject(forKey: key)
        remote?.clear()
    }

    /// デバッグメニューなど外部から保存内容を書き換えたときに投げる通知。ルート画面はこれを受けてセッションを作り直す
    static let didChange = Notification.Name("TripSessionStore.didChange")

    static func notifyChanged() {
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
