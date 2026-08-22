//
//  ShieldService.swift
//  SPAJAM2026App
//
//  スクリーンタイム(FamilyControls / ManagedSettings)で旅行中に他アプリをシールドする。
//  実機 + Family Controls capability が必要。認可されない環境では何もしない(任意機能)。
//

import Foundation
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif

@MainActor
@Observable
final class ShieldService {
    private(set) var isAuthorized = false
    private(set) var isShielding = false

    #if canImport(FamilyControls)
    var selection = FamilyActivitySelection()
    private let store = ManagedSettingsStore()
    #endif

    /// シールド対象を選んでいるか
    var hasSelection: Bool { selectionCount > 0 }

    /// シールド対象の数(OFFLINE SCORE の制限数ボーナスに使用)
    var selectionCount: Int {
        #if canImport(FamilyControls)
        return selection.applicationTokens.count + selection.categoryTokens.count
        #else
        return 0
        #endif
    }

    /// 保存済みの選択を戻し、既に認可済みなら isAuthorized も復元する
    func restore(selectionData: Data?) {
        #if canImport(FamilyControls)
        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if let selectionData,
           let restored = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selectionData) {
            selection = restored
        }
        #endif
    }

    /// 永続化用に選択を JSON にする
    var selectionData: Data? {
        #if canImport(FamilyControls)
        return try? JSONEncoder().encode(selection)
        #else
        return nil
        #endif
    }

    func requestAuthorization() async {
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            isAuthorized = true
        } catch {
            NSLog("[Shield] authorization failed: \(error)")
            isAuthorized = false
        }
        #endif
    }

    /// 選択したアプリ/カテゴリをシールドする(失敗しても旅行は続行できる)
    func start() {
        #if canImport(FamilyControls)
        guard isAuthorized, hasSelection else { return }
        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        isShielding = true
        #endif
    }

    /// デバッグ用: セッションの状態に関係なく、OS に残っているシールドと全制限を強制解除する
    static func forceClearAll() {
        #if canImport(FamilyControls)
        ManagedSettingsStore().clearAllSettings()
        #endif
    }

    func stop() {
        #if canImport(FamilyControls)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isShielding = false
        #endif
    }
}
