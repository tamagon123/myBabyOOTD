// =============================================================================
// ファイル名: SubscriptionManager.swift
// 役割: サブスクリプション状態の管理と広告非表示フラグの提供
// 説明:
//   将来的なサブスクリプション機能（StoreKit/RevenueCat等）の導入に備えた
//   管理クラスです。現時点では「広告を非表示にするか」の状態のみを管理します。
//   サブスクリプションの購入・検証ロジックは TODO として明示してあります。
//
//   【将来的なサブスクリプション実装手順】
//   1. App Store Connect で「月額プラン」などのサブスクリプション商品を作成
//      → productId に取得したプロダクトIDを設定
//   2. StoreKit 2 または RevenueCat SDK を導入
//   3. purchase() / restorePurchases() の TODO 箇所を実装
//   4. サーバーサイド検証（任意）
// =============================================================================

import SwiftUI
import Combine

// MARK: - サブスクリプション商品ID設定
// App Store Connect で作成した商品IDを設定してください
private enum SubscriptionConfig {
    // 広告非表示プラン（月額）
    // TODO: App Store Connect で作成後に設定
    static let removeAdsProductId: String = "com.yourapp.removeads.monthly"
}

// MARK: - SubscriptionManager

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // 広告を非表示にするか（サブスク購入済み or デバッグ中はtrue）
    @Published var isAdsRemoved: Bool = false

    // サブスクリプション購入済みかどうか
    @Published var isSubscribed: Bool = false

    // 購入/復元処理中フラグ
    @Published var isPurchasing: Bool = false

    // エラーメッセージ
    @Published var errorMessage: String? = nil

    private init() {
        loadFromUserDefaults()
    }

    // =============================================================================
    // 【関数サマリー】loadFromUserDefaults
    // 目的: アプリ起動時にローカル保存されたサブスク状態を読み込む
    // 備考: サーバー検証を導入した場合はここで検証APIを呼び出す
    // =============================================================================
    private func loadFromUserDefaults() {
        isSubscribed = UserDefaults.standard.bool(forKey: "subscription_isSubscribed")
        isAdsRemoved = isSubscribed
    }

    // =============================================================================
    // 【関数サマリー】purchase
    // 目的: 広告非表示サブスクリプションを購入する
    // 現状: TODO プレースホルダー（StoreKit 2 / RevenueCat 実装時に差し替え）
    // =============================================================================
    func purchase() async {
        // TODO: StoreKit 2 または RevenueCat で実装
        // 実装例 (StoreKit 2):
        //   let products = try await Product.products(for: [SubscriptionConfig.removeAdsProductId])
        //   guard let product = products.first else { return }
        //   let result = try await product.purchase()
        //   switch result {
        //   case .success(let verification):
        //       let transaction = try verification.payloadValue
        //       await transaction.finish()
        //       setSubscribed(true)
        //   case .userCancelled: break
        //   case .pending: break
        //   }

        isPurchasing = true
        defer { isPurchasing = false }

        // デバッグ用: 2秒後に購入成功を模倣（本番では削除）
        #if DEBUG
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        setSubscribed(true)
        #else
        errorMessage = "サブスクリプション機能は近日公開予定です"
        #endif
    }

    // =============================================================================
    // 【関数サマリー】restorePurchases
    // 目的: 過去の購入を復元する（機種変更時など）
    // 現状: TODO プレースホルダー
    // =============================================================================
    func restorePurchases() async {
        // TODO: StoreKit 2 または RevenueCat で実装
        // 実装例 (StoreKit 2):
        //   try await AppStore.sync()
        //   for await result in Transaction.currentEntitlements {
        //       if case .verified(let transaction) = result,
        //          transaction.productID == SubscriptionConfig.removeAdsProductId {
        //           setSubscribed(true)
        //           return
        //       }
        //   }
        //   setSubscribed(false)

        isPurchasing = true
        defer { isPurchasing = false }

        #if DEBUG
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        errorMessage = "デバッグ環境では復元できません"
        #else
        errorMessage = "サブスクリプション機能は近日公開予定です"
        #endif
    }

    // =============================================================================
    // 【関数サマリー】setSubscribed
    // 目的: サブスク状態を設定し、UserDefaultsに永続保存する
    // =============================================================================
    func setSubscribed(_ subscribed: Bool) {
        isSubscribed = subscribed
        isAdsRemoved = subscribed
        UserDefaults.standard.set(subscribed, forKey: "subscription_isSubscribed")
    }
}
