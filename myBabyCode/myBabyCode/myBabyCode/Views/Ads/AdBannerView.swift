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
//   5. Google-Mobile-Ads-SDK v11+ を使用（旧版 API とは異なる）
//
//   【現在の状態】
//   AdMob SDK 導入済み。canImport でコンパイル分岐し、未導入時は EmptyView。
//   子供向けアプリ対応として tagForChildDirectedTreatment を設定済み。
// =============================================================================

import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - AdMob 設定
private enum AdConfig {
    // 本番広告ユニットID（テスト時は ca-app-pub-3940256099942544/2934735716 に差し替え）
    //static let bannerAdUnitId: String = "ca-app-pub-1810074247562384/5573930888"
    // テスト用
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
        #if canImport(GoogleMobileAds)
        //--- AdMob 実装（SDK導入済みの場合のみ表示） ---
        GADBannerViewRepresentable(adUnitId: AdConfig.bannerAdUnitId)
            .frame(maxWidth: .infinity)
            .frame(height: AdConfig.bannerHeight)
        #else
        // AdMob SDK が未導入の場合は何も表示しない
        EmptyView()
        #endif
    }
}

// =============================================================================
// MARK: - GADBannerViewRepresentable
// 役割: UIKit の GADBannerView を SwiftUI でラップする
// 使い方: AdMob SDK 導入後にコメントを外して使用
// =============================================================================

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

struct GADBannerViewRepresentable: UIViewRepresentable {
    let adUnitId: String

    func makeUIView(context: Context) -> GADBannerView {
        // Calculate an adaptive banner size for the current width
        let screenWidth = UIScreen.main.bounds.width
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(screenWidth)

        let banner = GADBannerView(adSize: adSize)
        banner.adUnitID = adUnitId
        banner.rootViewController = Self.topViewController()

        // COPPA: child-directed treatment
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["tag_for_child_directed_treatment": "true"]
        request.register(extras)

        banner.load(request)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // If the size class or width changes significantly, you could recalc the adaptive size.
        // For simplicity, no dynamic updates are performed here.
    }
}

private extension GADBannerViewRepresentable {
    // Safely find the top-most view controller to host the banner
    static func topViewController(base: UIViewController? = UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = base as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = base?.presentedViewController { return topViewController(base: presented) }
        return base
    }
}
#endif
