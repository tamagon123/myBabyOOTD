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
    // 本番広告ユニットID
    static let bannerAdUnitId: String = "ca-app-pub-1810074247562384/5573930888"

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
        // GeometryReaderで実際の表示幅を取得し、iPadサイドバー分を除いた正確な幅でバナーを生成
        GeometryReader { geo in
            GADBannerViewRepresentable(adUnitId: AdConfig.bannerAdUnitId, width: geo.size.width)
                .frame(width: geo.size.width, height: AdConfig.bannerHeight)
        }
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
    let width: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> GADBannerView {
        // 標準バナーサイズ（320×50pt）を使用
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitId
        banner.rootViewController = Self.topViewController()
        banner.delegate = context.coordinator

        // テストデバイス設定（シミュレーターは自動的にテストモード）
        #if DEBUG
        // デバッグビルド時のテストデバイスID（実機のIDを追加）
        GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [
            "0a6d9df5c600163ec2922fc6f235afeb"  // iPhone実機
        ]
        #endif

        loadAd(on: banner)
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        // rootViewControllerを常に最新に更新（ゲスト→ログイン遷移でnilになるケースに対応）
        uiView.rootViewController = Self.topViewController()
    }

    private func loadAd(on banner: GADBannerView) {
        // width が 0 の場合はロードしない（GeometryReader初回レンダリング時の0サイズ対策）
        guard width > 0 else { return }

        // COPPA: child-directed treatment
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["tag_for_child_directed_treatment": "true"]
        request.register(extras)

        banner.load(request)
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[Banner] Ad loaded successfully")
        }
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[Banner] Failed to load ad: \(error.localizedDescription)")
        }
        func bannerViewDidRecordImpression(_ bannerView: GADBannerView) {
            print("[Banner] Ad impression recorded")
        }
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
