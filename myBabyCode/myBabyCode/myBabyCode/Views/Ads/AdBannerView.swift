// =============================================================================
// ファイル名: AdBannerView.swift
// 役割: AdMob バナー広告の表示ラッパー（サブスク未加入時のみ表示）
// 説明:
//   Google AdMob のバナー広告を表示するビューです。
//   SubscriptionManager.isAdsRemoved が true の場合は非表示になります。
//
//   【セットアップ手順（AdMob）】
//   1. https://admob.google.com/ でアプリを登録
//   2. アプリID（ca-app-pub-XXXX~XXXX）を Info.plist の GADApplicationIdentifier に設定
//   3. バナー広告ユニットを作成し、adUnitId に設定（下記 AdConfig.bannerAdUnitId）
//   4. Google-Mobile-Ads-SDK を Swift Package Manager で追加
//      URL: https://github.com/googleads/swift-package-manager-google-mobile-ads
//   5. このファイル内の「#if ADMOB_ENABLED」ブロックのコメントを外す
//
//   【現在の状態】
//   AdMob SDK 未導入のため、プレースホルダー（グレー帯）を表示しています。
//   SDK 導入後に ADMOB_ENABLED フラグを有効にしてください。
// =============================================================================

import SwiftUI

// MARK: - AdMob 設定
private enum AdConfig {
    // テスト用広告ユニットID（本番では実際のIDに差し替えること）
    // テストID: ca-app-pub-3940256099942544/2934735716
    static let bannerAdUnitId: String = "ca-app-pub-3940256099942544/2934735716"

    // バナーの標準高さ
    static let bannerHeight: CGFloat = 50
}

// MARK: - AdBannerView
// サブスク未加入時のみ広告バナーを表示するビュー

struct AdBannerView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        if !subscriptionManager.isAdsRemoved {
            adContent
        }
    }

    @ViewBuilder
    private var adContent: some View {
        // ==========================================================================
        // TODO: AdMob SDK 導入後にこのプレースホルダーを実際の広告ビューに差し替える
        //
        // 【差し替え手順】
        // 1. Google-Mobile-Ads-SDK を追加（SPM）
        // 2. 下記コメントアウトを外してプレースホルダーを削除
        // 3. AdConfig.bannerAdUnitId を本番IDに変更
        // ==========================================================================

        // --- プレースホルダー（SDK未導入時の表示） ---
        ZStack {
            Color(.systemGray5)
                .frame(height: AdConfig.bannerHeight)
            Text("広告スペース（AdMob 設定後に表示されます）")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: AdConfig.bannerHeight)

        // --- AdMob 実装例（SDK導入後にコメントを外す） ---
        // GADBannerViewRepresentable(adUnitId: AdConfig.bannerAdUnitId)
        //     .frame(maxWidth: .infinity)
        //     .frame(height: AdConfig.bannerHeight)
    }
}

// =============================================================================
// MARK: - GADBannerViewRepresentable
// 役割: UIKit の GADBannerView を SwiftUI でラップする
// 使い方: AdMob SDK 導入後にコメントを外して使用
// =============================================================================

// import GoogleMobileAds
//
// struct GADBannerViewRepresentable: UIViewRepresentable {
//     let adUnitId: String
//
//     func makeUIView(context: Context) -> BannerView {
//         let banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(
//             width: UIScreen.main.bounds.width
//         ))
//         banner.adUnitID = adUnitId
//         banner.rootViewController = UIApplication.shared
//             .connectedScenes
//             .compactMap { $0 as? UIWindowScene }
//             .first?.windows.first?.rootViewController
//         banner.load(Request())
//         return banner
//     }
//
//     func updateUIView(_ uiView: BannerView, context: Context) {}
// }
