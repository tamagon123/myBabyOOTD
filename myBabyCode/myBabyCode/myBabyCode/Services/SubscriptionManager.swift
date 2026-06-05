// =============================================================================
// ファイル名: SubscriptionManager.swift
// 役割: プレミアムプラン（買い切り）の購入状態管理
// 説明:
//   買い切り型（Non-Consumable）のプレミアムプランを管理します。
//   購入済みの場合、広告非表示とカレンダー編集期間拡張（1年前まで）が有効になります。
//
//   【App Store Connect での設定手順】
//   1. App Store Connect → App 内課金 → 「消耗型以外」で商品を作成
//   2. 製品IDを PremiumConfig.productId と完全一致させること
//   3. サンドボックスアカウントでテスト購入を実施
// =============================================================================

import SwiftUI
import Combine
import StoreKit

// MARK: - プレミアムプラン商品ID設定
private enum PremiumConfig {
    static let productId: String = "com.tamagon.Nanikiru.premium"
}

// MARK: - SubscriptionManager

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // プレミアム購入済みかどうか（広告非表示＋カレンダー拡張が有効）
    @Published var isPremium: Bool = false

    // 購入/復元処理中フラグ
    @Published var isPurchasing: Bool = false

    // エラーメッセージ
    @Published var errorMessage: String? = nil

    // StoreKit 商品情報（価格表示用）
    @Published var product: Product? = nil
    @Published var productPrice: String? = nil

    // 後方互換プロパティ（既存Viewとの互換性維持）
    var isSubscribed: Bool { isPremium }
    var isAdsRemoved: Bool { isPremium }

    private init() {
        loadFromUserDefaults()
        // StoreKit 2 のトランザクション更新を監視開始
        listenForTransactionUpdates()
    }

    // =============================================================================
    // 【関数サマリー】loadFromUserDefaults
    // 目的: アプリ起動時にローカル保存されたサブスク状態を読み込む
    // 備考: サーバー検証を導入した場合はここで検証APIを呼び出す
    // =============================================================================
    private func loadFromUserDefaults() {
        isPremium = UserDefaults.standard.bool(forKey: "premium_isPurchased")
    }

    // =============================================================================
    // 【関数サマリー】loadProduct
    // 目的: StoreKit 2 から商品情報を取得し、価格を UI に反映する
    // =============================================================================
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [PremiumConfig.productId])
            if let product = products.first {
                self.product = product
                self.productPrice = product.displayPrice
            }
        } catch {
            print("[StoreKit] Failed to load product: \(error.localizedDescription)")
        }
    }

    // =============================================================================
    // 【関数サマリー】purchase
    // 目的: StoreKit 2 で広告非表示サブスクリプションを購入する
    // =============================================================================
    func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            let products = try await Product.products(for: [PremiumConfig.productId])
            guard let product = products.first else {
                errorMessage = "商品情報を取得できませんでした"
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    setPremium(true)
                case .unverified(_, let error):
                    errorMessage = "購入の検証に失敗しました: \(error.localizedDescription)"
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "購入が保留されています。承認後に反映されます"
            @unknown default:
                errorMessage = "予期しない購入結果が返りました"
            }
        } catch {
            errorMessage = "購入に失敗しました: \(error.localizedDescription)"
        }
    }

    // =============================================================================
    // 【関数サマリー】restorePurchases
    // 目的: StoreKit 2 で過去の購入を復元する（機種変更時など）
    // =============================================================================
    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        do {
            try await AppStore.sync()
            await loadCurrentEntitlements()
        } catch {
            errorMessage = "復元に失敗しました: \(error.localizedDescription)"
        }
    }

    // =============================================================================
    // 【関数サマリー】setPremium
    // 目的: プレミアム状態を設定し、UserDefaultsに永続保存する
    // =============================================================================
    func setPremium(_ purchased: Bool) {
        isPremium = purchased
        UserDefaults.standard.set(purchased, forKey: "premium_isPurchased")
    }

    // =============================================================================
    // 【関数サマリー】loadCurrentEntitlements
    // 目的: StoreKit 2 の currentEntitlements で現在の購入権利を確認する
    // 呼び出し元: init() 時、restorePurchases() 後、トランザクション更新時
    // =============================================================================
    private func loadCurrentEntitlements() async {
        var hasPurchased = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == PremiumConfig.productId {
                    hasPurchased = true
                }
            case .unverified(_, let error):
                print("[StoreKit] Unverified transaction: \(error.localizedDescription)")
            }
        }
        setPremium(hasPurchased)
    }

    // =============================================================================
    // 【関数サマリー】listenForTransactionUpdates
    // 目的: StoreKit 2 のトランザクション更新を監視し、購入状態を自動反映する
    // 備考: アプリ起動後に開始。購入完了・返金・サブスク更新時に自動で呼ばれる
    // =============================================================================
    private func listenForTransactionUpdates() {
        // Capture product ID outside the task to avoid cross-actor access
        let productId = PremiumConfig.productId
        Task { [weak self] in
            // This Task inherits the @MainActor from SubscriptionManager
            for await result in Transaction.updates {
                guard let self = self else { return }
                switch result {
                case .verified(let transaction):
                    if transaction.productID == productId {
                        self.setPremium(true)
                    }
                    await transaction.finish()
                case .unverified(_, let error):
                    print("[StoreKit] Unverified update: \(error.localizedDescription)")
                }
            }
        }
    }

}
