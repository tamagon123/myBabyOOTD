// =============================================================================
// ファイル名: GuestInterstitialManager.swift
// 役割: ゲストログイン中のインタースティシャル広告管理
// 説明:
//   ゲストモード中、60秒ごとにアラートを表示する。
//   ユーザーが「広告を見て続ける」を選択した場合はインタースティシャル広告を再生し、
//   視聴後に60秒タイマーをリセットしてゲスト継続。
//   「ログイン / 新規登録」を選択した場合は isGuest = false にして AuthView へ遷移。
// =============================================================================

import SwiftUI
import Combine
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - 広告ユニットID設定
private enum GuestAdConfig {
    static let interstitialAdUnitId: String = "ca-app-pub-1810074247562384/7562532493"
    static let intervalSeconds: TimeInterval = 60
}

// MARK: - GuestInterstitialManager

@MainActor
final class GuestInterstitialManager: NSObject, ObservableObject {
    static let shared = GuestInterstitialManager()

    // アラート表示トリガー
    @Published var showPrompt: Bool = false

    private var timer: AnyCancellable?
    private var isRunning = false

    #if canImport(GoogleMobileAds)
    private var interstitial: GADInterstitialAd?
    #endif

    private override init() {
        super.init()
    }

    // MARK: - タイマー開始（ゲストログイン時に呼ぶ）

    func start() {
        guard !isRunning else { return }
        isRunning = true
        preloadAd()
        scheduleNext()
    }

    // MARK: - タイマー停止（ゲスト終了時に呼ぶ）

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        showPrompt = false
    }

    // MARK: - 次のアラートをスケジュール

    private func scheduleNext() {
        timer?.cancel()
        timer = Just(())
            .delay(for: .seconds(GuestAdConfig.intervalSeconds), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.showPrompt = true
            }
    }

    // MARK: - 「広告を見て続ける」選択時

    func watchAdAndContinue(from viewController: UIViewController?) {
        #if canImport(GoogleMobileAds)
        if let ad = interstitial, let vc = viewController {
            ad.present(fromRootViewController: vc)
        }
        #endif
        // 広告ロード失敗時もゲスト継続としてタイマーリセット
        continueAsGuest()
    }

    // MARK: - ゲスト継続（広告終了後 or ロード失敗）

    func continueAsGuest() {
        showPrompt = false
        preloadAd()
        scheduleNext()
    }

    // MARK: - 広告プリロード

    private func preloadAd() {
        #if canImport(GoogleMobileAds)
        let request = GADRequest()
        GADInterstitialAd.load(
            withAdUnitID: GuestAdConfig.interstitialAdUnitId,
            request: request
        ) { [weak self] ad, error in
            if let error {
                print("[GuestAd] load failed: \(error.localizedDescription)")
                self?.interstitial = nil
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            print("[GuestAd] loaded successfully")
        }
        #endif
    }
}

// MARK: - GADFullScreenContentDelegate

#if canImport(GoogleMobileAds)
extension GuestInterstitialManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("[GuestAd] dismissed")
            self.continueAsGuest()
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("[GuestAd] failed to present: \(error.localizedDescription)")
            self.continueAsGuest()
        }
    }
}
#endif
