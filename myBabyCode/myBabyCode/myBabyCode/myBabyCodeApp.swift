// =============================================================================
// ファイル名: myBabyCodeApp.swift
// 役割: アプリケーションのエントリーポイント（最初に実行されるファイル）
// 説明:
//   このファイルはiOSアプリ「Nanikiru」（ベビー服コーディネート共有アプリ）の
//   起動口です。Firebaseの初期設定、データベースのオフラインキャッシュ設定、
//   そしてユーザーのログイン状態に応じて最初に表示する画面を決定します。
//   SwiftUIの@mainマーカーが付いているため、アプリ起動時に自動的に呼ばれます。
// =============================================================================

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

@main
struct myBabyCodeApp: App {
    // AppDelegateをSwiftUIに接続（プッシュ通知などのライフサイクル処理を委譲）
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // 認証状態を管理するViewModel。アプリ全体で共有される。
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.scenePhase) var scenePhase

    // =============================================================================
    // 【関数サマリー】init
    // 目的: アプリ起動時に一度だけ実行される初期化処理
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebaseの各種サービス（Auth, Firestore, Storageなど）を初期化
    //   2. Firestore（データベース）のオフライン永続化を有効化
    //   3. キャッシュサイズを100MBに設定（通信節約・オフライン対応）
    // 備考: このinitが終わる前にFirebase関連の処理を呼ぶとクラッシュするため、
    //       必ず最初にFirebaseApp.configure()を呼ぶ必要があります。
    // =============================================================================
    init() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: 100 * 1024 * 1024))
        Firestore.firestore().settings = settings

        applyCustomFont()
    }

    private func applyCustomFont() {
        UIFont.swizzleSystemFont()
    }

    // =============================================================================
    // 【関数サマリー】body
    // 目的: アプリの画面構成（Scene）を定義する。SwiftUIでは必須のプロパティ。
    // 引数: なし
    // 戻り値: Scene（WindowGroup）
    // 処理の流れ:
    //   1. アプリの初期化中（isInitializing）→ SplashView（ローディング画面）
    //   2. 未ログイン → AuthView（ログイン・新規登録画面）
    //   3. ログイン済み＆プロフィール未完了 → ProfileSetupView（初回設定画面）
    //   4. ログイン済み＆プロフィール完了 → MainTabView（ホーム/検索/マイページ）
    // 呼び出し元: システム（iOS起動時に自動呼び出し）
    // 備考: authViewModelの状態変化に応じて自動で表示画面が切り替わります。
    // =============================================================================
    var body: some Scene {
        WindowGroup {
            if authViewModel.isInitializing {
                // 初期化中: アプリロゴと読み込みインジケータを表示
                SplashView()
            } else if authViewModel.isSignedIn {
                // ログイン済み
                if authViewModel.needsProfileSetup {
                    // プロフィール未設定: 初回登録画面を表示
                    ProfileSetupView()
                        .environmentObject(authViewModel)
                } else {
                    // 通常利用: メインタブ（ホーム・検索・マイページ）
                    MainTabView()
                        .environmentObject(authViewModel)
                }
            } else {
                // 未ログイン: 認証画面を表示
                AuthView()
                    .environmentObject(authViewModel)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // UIが完全にアクティブになってから1秒後にATTダイアログを表示
                // （iOS 15以降では即時呼び出しだとシステムに無視される場合があるため遅延）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    appDelegate.requestATT()
                }
            }
        }
    }
}
