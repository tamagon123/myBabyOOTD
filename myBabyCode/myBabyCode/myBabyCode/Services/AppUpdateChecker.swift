// =============================================================================
// ファイル名: AppUpdateChecker.swift
// 役割: App Storeの最新バージョンをチェックし、アップデート通知を管理する
// 説明:
//   iTunes Lookup APIを使ってApp Storeの最新バージョンを取得し、
//   インストール済みのバージョンと比較します。
//   新しいバージョンがある場合、毎回起動時にアラートを表示します。
// =============================================================================

import SwiftUI
import Combine

// MARK: - 設定
private enum AppUpdateConfig {
    static let appStoreId: String = "6775408521"
    static let appStoreUrl: String = "https://apps.apple.com/app/id\(appStoreId)"
    static let lookupUrl: String = "https://itunes.apple.com/lookup?id=\(appStoreId)&country=jp"
}

// MARK: - AppUpdateChecker

final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published var isUpdateAvailable: Bool = false
    @Published var latestVersion: String = ""

    private init() {}

    // 現在インストール済みのバージョン
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // App Storeの最新バージョンを取得してチェック
    func checkForUpdate() async {
        guard let url = URL(string: AppUpdateConfig.lookupUrl) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let results = json["results"] as? [[String: Any]],
                let storeVersion = results.first?["version"] as? String
            else { return }

            let newer = isNewer(storeVersion, than: currentVersion)
            await MainActor.run {
                latestVersion = storeVersion
                isUpdateAvailable = newer
            }
        } catch {
            print("[AppUpdateChecker] バージョンチェック失敗: \(error.localizedDescription)")
        }
    }

    // App Storeを開く
    func openAppStore() {
        guard let url = URL(string: AppUpdateConfig.appStoreUrl) else { return }
        UIApplication.shared.open(url)
    }

    // バージョン比較: a が b より新しければ true
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aComponents = a.split(separator: ".").compactMap { Int($0) }
        let bComponents = b.split(separator: ".").compactMap { Int($0) }
        let maxLen = max(aComponents.count, bComponents.count)
        for i in 0..<maxLen {
            let aVal = i < aComponents.count ? aComponents[i] : 0
            let bVal = i < bComponents.count ? bComponents[i] : 0
            if aVal > bVal { return true }
            if aVal < bVal { return false }
        }
        return false
    }
}
