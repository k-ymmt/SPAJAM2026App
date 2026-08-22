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
    var hasSelection: Bool {
        #if canImport(FamilyControls)
        return !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
        #else
        return false
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

    func stop() {
        #if canImport(FamilyControls)
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isShielding = false
        #endif
    }
}
