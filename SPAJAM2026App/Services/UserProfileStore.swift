//
//  UserProfileStore.swift
//  SPAJAM2026App
//
//  ユーザープロフィール(表示名)のローカル保存。
//  認証は匿名(FirebaseBootstrap)のままにし、名前だけを持つ。
//  ルームの親メンバー名・招待コード参加時のデフォルト名として使う。
//

import Foundation

enum UserProfileStore {
    private static let nameKey = "userProfile.name"

    /// 登録済みの表示名。未登録なら nil
    static var name: String? {
        get {
            let value = UserDefaults.standard.string(forKey: nameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty ?? true) ? nil : value
        }
        set {
            UserDefaults.standard.set(newValue, forKey: nameKey)
        }
    }
}
