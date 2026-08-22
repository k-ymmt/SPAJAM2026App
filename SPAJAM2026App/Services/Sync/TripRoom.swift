//
//  TripRoom.swift
//  SPAJAM2026App
//
//  複数人で旅をするための「ルーム」。招待コードがドキュメント ID。
//  Firestore: rooms/{code}(TripRoom)、rooms/{code}/members/{uid}(RoomMember)
//

import Foundation

nonisolated struct TripRoom: Codable, Sendable, Equatable {
    enum Status: String, Codable, Sendable {
        case waiting  // 親がプランを作成中(子は待機)
        case started  // 親が「旅をはじめる」を押し、plan が公開された
    }

    var hostUid: String
    /// 親を含む人数(2〜5)
    var partySize: Int
    var status: Status
    var plan: TravelPlan?
    var createdAt: Date

    /// 子として参加できる残り枠
    var guestCapacity: Int { max(0, partySize - 1) }
}

/// 招待コードで参加した子 1 人
nonisolated struct RoomMember: Codable, Sendable, Identifiable, Equatable {
    /// uid
    var id: String
    var name: String
    var joinedAt: Date
}

/// 自分がどのルームにどの役割で属しているか。TripSession のスナップショットにも保存する
nonisolated struct RoomMembership: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case host   // 親: プラン作成者
        case guest  // 子: 招待コードで参加した人
    }

    var code: String
    var role: Role
    /// 子が入力したユーザー名(親は nil)
    var name: String?
}

nonisolated enum TripRoomError: LocalizedError, Equatable {
    case notConfigured
    case notSignedIn
    case notFound
    case alreadyStarted
    case full
    case invalidName

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Firebase が設定されていません(GoogleService-Info.plist を配置してください)"
        case .notSignedIn: "サインインできませんでした。通信環境を確認してください"
        case .notFound: "招待コードが見つかりません"
        case .alreadyStarted: "この旅はすでに始まっています"
        case .full: "このルームは定員に達しています"
        case .invalidName: "ユーザー名を入力してください"
        }
    }
}

/// 招待コード(6 文字)。紛らわしい文字(0/O, 1/I)は使わない
nonisolated enum InviteCode {
    static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    static func generate(using generator: inout some RandomNumberGenerator) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    /// 入力を正規化(大文字化・空白除去)。形式が合わなければ nil
    static func normalize(_ input: String) -> String? {
        let code = input.uppercased().filter { !$0.isWhitespace }
        guard code.count == length, code.allSatisfy({ alphabet.contains($0) }) else { return nil }
        return code
    }
}
