//
//  TripRoomService.swift
//  SPAJAM2026App
//
//  ルーム(招待コード)の Firestore 操作。作成・参加・プラン公開・購読。
//  Firestore.firestore() は FirebaseApp.configure() 後にしか呼べないので、各メソッド内で取得する。
//

import FirebaseFirestore
import Foundation

@MainActor
final class TripRoomService {
    static let shared = TripRoomService()

    private init() {}

    private func db() throws -> Firestore {
        guard FirebaseBootstrap.isConfigured else { throw TripRoomError.notConfigured }
        return Firestore.firestore()
    }

    private func roomRef(_ code: String) throws -> DocumentReference {
        try db().collection("rooms").document(code)
    }

    // MARK: - 親

    /// 未使用の招待コードでルームを作り、コードを返す
    func createRoom(partySize: Int) async throws -> String {
        let uid = try await AuthService.shared.signInIfNeeded()
        for _ in 0..<5 {
            let code = InviteCode.generate()
            let ref = try roomRef(code)
            if try await ref.getDocument().exists { continue }
            let room = TripRoom(hostUid: uid, partySize: partySize, status: .waiting, plan: nil, createdAt: Date())
            try ref.setData(from: room)
            return code
        }
        throw TripRoomError.notSignedIn
    }

    func updatePartySize(code: String, partySize: Int) async throws {
        try await roomRef(code).updateData(["partySize": partySize])
    }

    /// 「旅をはじめる」: プランを公開し、待機中の子を開始させる
    func publishPlan(code: String, plan: TravelPlan) async throws {
        let encoded = try Firestore.Encoder().encode(plan)
        try await roomRef(code).updateData(["plan": encoded, "status": TripRoom.Status.started.rawValue])
    }

    func deleteRoom(code: String) async throws {
        try await roomRef(code).delete()
    }

    // MARK: - 子

    /// 招待コードで参加する。満員・開始済みなら失敗
    func join(code: String, name: String) async throws -> RoomMembership {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20 else { throw TripRoomError.invalidName }
        let uid = try await AuthService.shared.signInIfNeeded()
        let ref = try roomRef(code)
        let snapshot = try await ref.getDocument()
        guard snapshot.exists, let room = try? snapshot.data(as: TripRoom.self) else { throw TripRoomError.notFound }
        guard room.status == .waiting else { throw TripRoomError.alreadyStarted }
        let members = try await ref.collection("members").getDocuments().documents
        if !members.contains(where: { $0.documentID == uid }), members.count >= room.guestCapacity {
            throw TripRoomError.full
        }
        try ref.collection("members").document(uid)
            .setData(from: RoomMember(id: uid, name: trimmed, joinedAt: Date()))
        return RoomMembership(code: code, role: .guest, name: trimmed)
    }

    func leave(code: String) async throws {
        let uid = try await AuthService.shared.signInIfNeeded()
        try await roomRef(code).collection("members").document(uid).delete()
    }

    // MARK: - 購読

    func observeRoom(code: String, onChange: @escaping @MainActor (TripRoom?) -> Void) -> ListenerRegistration? {
        try? roomRef(code).addSnapshotListener { snapshot, _ in
            let room = snapshot.flatMap { try? $0.data(as: TripRoom.self) }
            MainActor.assumeIsolated { onChange(room) }
        }
    }

    func observeMembers(code: String, onChange: @escaping @MainActor ([RoomMember]) -> Void) -> ListenerRegistration? {
        try? roomRef(code).collection("members").order(by: "joinedAt").addSnapshotListener { snapshot, _ in
            let members = snapshot?.documents.compactMap { try? $0.data(as: RoomMember.self) } ?? []
            MainActor.assumeIsolated { onChange(members) }
        }
    }
}

/// ルームと参加者をリアルタイムに監視する Observable。画面の .task(id:) から start し、deinit で止める
@MainActor
@Observable
final class TripRoomObserver {
    private(set) var room: TripRoom?
    private(set) var members: [RoomMember] = []
    /// 購読中のコード
    private(set) var code: String?
    private var roomListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    /// 子の参加人数が揃ったか(親を除いた定員に達したか)
    var isPartyComplete: Bool {
        guard let room else { return false }
        return members.count >= room.guestCapacity
    }

    func start(code: String) {
        guard self.code != code else { return }
        stop()
        self.code = code
        roomListener = TripRoomService.shared.observeRoom(code: code) { [weak self] in self?.room = $0 }
        membersListener = TripRoomService.shared.observeMembers(code: code) { [weak self] in self?.members = $0 }
    }

    func stop() {
        roomListener?.remove()
        membersListener?.remove()
        roomListener = nil
        membersListener = nil
        code = nil
        room = nil
        members = []
    }

    isolated deinit {
        roomListener?.remove()
        membersListener?.remove()
    }
}
