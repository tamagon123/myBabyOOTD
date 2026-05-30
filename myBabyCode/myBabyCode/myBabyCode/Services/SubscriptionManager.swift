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
import StoreKit

// MARK: - サブスクリプション商品ID設定
// App Store Connect で作成した商品IDを設定してください
private enum SubscriptionConfig {
    // 広告非表示プラン（月額）
    // TODO: App Store Connect で作成後に実際のProduct IDに変更
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

    // StoreKit 商品情報（価格表示用）
    @Published var product: Product? = nil
    @Published var productPrice: String? = nil

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
        isSubscribed = UserDefaults.standard.bool(forKey: "subscription_isSubscribed")
        isAdsRemoved = isSubscribed
    }

    // =============================================================================
    // 【関数サマリー】loadProduct
    // 目的: StoreKit 2 から商品情報を取得し、価格を UI に反映する
    // =============================================================================
    func loadProduct() async {
        #if DEBUG
        if !_isStoreKitTestingAvailable { return }
        #endif

        do {
            let products = try await Product.products(for: [SubscriptionConfig.removeAdsProductId])
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

        // DEBUG ビルドでかつ StoreKit Testing 未設定の場合はモック動作
        #if DEBUG
        // StoreKit Configuration File を使用していない場合のみモック
        if !_isStoreKitTestingAvailable {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            setSubscribed(true)
            return
        }
        #endif

        do {
            let products = try await Product.products(for: [SubscriptionConfig.removeAdsProductId])
            guard let product = products.first else {
                errorMessage = "商品情報を取得できませんでした"
                return
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // 購入成功。トランザクションを検証して完了させる
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    setSubscribed(true)
                case .unverified(_, let error):
                    errorMessage = "購入の検証に失敗しました: \(error.localizedDescription)"
                }
            case .userCancelled:
                // ユーザーがキャンセル（エラーではない）
                break
            case .pending:
                // 購入保留（保護者承認待ちなど）
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

        #if DEBUG
        if !_isStoreKitTestingAvailable {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            errorMessage = "デバッグ環境では復元できません（StoreKit Testing未設定）"
            return
        }
        #endif

        do {
            // App Store と同期（未完了トランザクションを同期）
            try await AppStore.sync()
            // 現在の有効な権利を確認
            await loadCurrentEntitlements()
        } catch {
            errorMessage = "復元に失敗しました: \(error.localizedDescription)"
        }
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

    // =============================================================================
    // 【関数サマリー】loadCurrentEntitlements
    // 目的: StoreKit 2 の currentEntitlements で現在の購入権利を確認する
    // 呼び出し元: init() 時、restorePurchases() 後、トランザクション更新時
    // =============================================================================
    private func loadCurrentEntitlements() async {
        var hasActiveSubscription = false
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                if transaction.productID == SubscriptionConfig.removeAdsProductId {
                    hasActiveSubscription = true
                }
            case .unverified(_, let error):
                print("[StoreKit] Unverified transaction: \(error.localizedDescription)")
            }
        }
        setSubscribed(hasActiveSubscription)
    }

    // =============================================================================
    // 【関数サマリー】listenForTransactionUpdates
    // 目的: StoreKit 2 のトランザクション更新を監視し、購入状態を自動反映する
    // 備考: アプリ起動後に開始。購入完了・返金・サブスク更新時に自動で呼ばれる
    // =============================================================================
    private func listenForTransactionUpdates() {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                switch result {
                case .verified(let transaction):
                    // 対象商品のトランザクションなら状態を更新
                    await MainActor.run {
                        if transaction.productID == SubscriptionConfig.removeAdsProductId {
                            self.setSubscribed(true)
                        }
                    }
                    await transaction.finish()
                case .unverified(_, let error):
                    print("[StoreKit] Unverified update: \(error.localizedDescription)")
                }
            }
        }
    }

    // =============================================================================
    // 【プロパティ】_isStoreKitTestingAvailable
    // 目的: DEBUG ビルド時に StoreKit Testing（Configuration File）が使えるか判定
    // 備考: StoreKit Configuration File を設定している場合はモックをスキップして
    //       実際の StoreKit 2 API を呼び出す
    // =============================================================================
    #if DEBUG
    private var _isStoreKitTestingAvailable: Bool {
        // StoreKit Testing 環境かどうかを判定
        // Configuration File を使う場合、processInfo などで判定可能
        // 簡易判定: シミュレータなら Testing 可能とみなす（実際には SKTestSession 等で確認）
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    #endif
}
