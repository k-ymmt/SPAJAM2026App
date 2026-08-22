//
//  FirebaseBootstrap.swift
//  SPAJAM2026App
//
//  Firebase の初期化と匿名サインイン。GoogleService-Info.plist(gitignore 済み)が無ければ
//  Firebase を構成せず、複数人機能だけが使えない状態でアプリは通常どおり動く。
//

import FirebaseAuth
import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    /// App 起動時に 1 回だけ呼ぶ。plist が無ければ何もしない
    static func configureIfPossible() {
        guard !isConfigured else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            NSLog("[Firebase] GoogleService-Info.plist が無いため Firebase を初期化しません(scripts/fetch-google-service-info.sh で取得)")
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        TripSessionStore.remote = FirestoreSessionStore()
        Task { _ = try? await AuthService.shared.signInIfNeeded() }
    }
}

/// 匿名認証。起動時に自動でサインインし、uid を Firestore のルールとドキュメント ID に使う
@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var uid: String?

    private init() {
        uid = FirebaseBootstrap.isConfigured ? Auth.auth().currentUser?.uid : nil
    }

    /// サインイン済みなら uid を返し、未サインインなら匿名サインインする
    @discardableResult
    func signInIfNeeded() async throws -> String {
        guard FirebaseBootstrap.isConfigured else { throw TripRoomError.notConfigured }
        if let uid = Auth.auth().currentUser?.uid {
            self.uid = uid
            return uid
        }
        let result = try await Auth.auth().signInAnonymously()
        uid = result.user.uid
        return result.user.uid
    }
}
