// =============================================================================
// ファイル名: AppDelegate.swift
// 役割: iOSアプリのライフサイクルイベントとプッシュ通知を管理
// 説明:
//   アプリが起動した時、バックグラウンドにいる時、プッシュ通知を受信した時など、
//   iOSシステムからのイベントを受け取るためのファイルです。
//   特にFirebase Cloud Messaging（FCM）のトークン取得・更新、
//   リモート通知（プッシュ通知）の表示設定を担当しています。
//   myBabyCodeApp.swiftから@UIApplicationDelegateAdaptorで接続されています。
// =============================================================================

import UIKit
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth
import UserNotifications
import AppTrackingTransparency
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {

    // =============================================================================
    // 【関数サマリー】application(_:didFinishLaunchingWithOptions:)
    // 目的: アプリが起動した際に呼ばれる初期化処理
    // 引数:
    //   - application: UIApplication - iOSシステムから渡されるアプリインスタンス
    //   - launchOptions: 起動時の追加情報（通常はnil）
    // 戻り値: Bool - trueで起動成功をシステムに通知
    // 処理の流れ:
    //   1. ユーザー通知センターのデリゲートを自身に設定（通知を受け取る準備）
    //   2. Firebase Messagingのデリゲートを自身に設定（FCMトークンを受け取る準備）
    //   3. AdMob 初期化と ATT（広告トラッキング）許可要求
    // 呼び出し元: iOSシステム（アプリ起動時に自動呼び出し）
    // 備考: 戻り値trueは「起続行してOK」という意味。
    // =============================================================================
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        // AdMob 初期化と ATT 許可要求（非同期）
        requestATTAndInitializeAdMob()

        return true
    }

    // =============================================================================
    // 【関数サマリー】requestATTAndInitializeAdMob
    // 目的: iOS 14.5 以降の ATT（App Tracking Transparency）許可を求め、
    //       レスポンス後に Google Mobile Ads SDK を初期化する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. iOS 14 以上なら ATT 許可ダイアログを表示
    //   2. ユーザーが許可/拒否しても MobileAds.shared.start() を呼び出し
    // 備考:
    //   - ATT 未許可でも広告は表示されるが、ターゲティング精度が低下する
    //   - 子供向けアプリでは tagForChildDirectedTreatment を設定すべき
    // =============================================================================
    private func requestATTAndInitializeAdMob() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        print("[AdMob] ATT authorized")
                    case .denied:
                        print("[AdMob] ATT denied")
                    case .notDetermined:
                        print("[AdMob] ATT not determined")
                    case .restricted:
                        print("[AdMob] ATT restricted")
                    @unknown default:
                        break
                    }
                    self.startAdMob()
                }
            }
        } else {
            // iOS 13 以前は ATT 不要
            startAdMob()
        }
    }

    private func startAdMob() {
        // AdMob SDK 初期化（v11+ API）
        GADMobileAds.sharedInstance().start { initializationStatus in
            let adapterStatuses = initializationStatus.adapterStatusesByClassName
            for (adapter, status) in adapterStatuses {
                print("[AdMob] \(adapter): \(status.state.rawValue)")
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
    // 目的: デバイスのリモート通知登録が成功した際にAPNsデバイストークンを受け取り、
    //       Firebase Messagingに渡す
    // 引数:
    //   - application: UIApplication
    //   - deviceToken: Data - Appleから発行されたデバイス固有のトークン
    // 戻り値: なし
    // 処理の流れ:
    //   1. 取得したデバイストークンをFirebase Messagingにセット
    //   2. これによりFCMトークンが発行される
    // 呼び出し元: iOSシステム（通知許可取得後に自動呼び出し）
    // 備考: ユーザーが初めてアプリを起動した時や、トークンが更新された時に呼ばれる。
    // =============================================================================
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // =============================================================================
    // 【関数サマリー】application(_:didFailToRegisterForRemoteNotificationsWithError:)
    // 目的: リモート通知の登録に失敗した際のエラーログ出力
    // 引数:
    //   - application: UIApplication
    //   - error: Error - 失敗原因
    // 戻り値: なし
    // 備考: シミュレータや通知拒否設定時に発生する可能性がある。
    // =============================================================================
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error.localizedDescription)")
    }
}

// MARK: - UNUserNotificationCenterDelegate
// 説明: アプリがフォアグラウンド（画面表示中）にいる時の通知表示制御を担当

extension AppDelegate: UNUserNotificationCenterDelegate {

    // =============================================================================
    // 【関数サマリー】userNotificationCenter(_:willPresent:withCompletionHandler:)
    // 目的: アプリが前面に表示されている状態で通知が届いた時の表示方法を決定
    // 引数:
    //   - center: UNUserNotificationCenter - 通知管理オブジェクト
    //   - notification: UNNotification - 受信した通知内容
    //   - completionHandler: 表示オプションを指定するコールバック
    // 戻り値: なし
    // 処理の流れ:
    //   1. バナー（画面上部の通知）、サウンド、バッジ（アプリアイコンの赤丸）を表示
    // 備考: この実装がないと、フォアグラウンド中は通知が静かに届いてしまう。
    // =============================================================================
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // =============================================================================
    // 【関数サマリー】userNotificationCenter(_:didReceive:withCompletionHandler:)
    // 目的: ユーザーが通知をタップした時の処理
    // 引数:
    //   - center: UNUserNotificationCenter
    //   - response: UNNotificationResponse - ユーザーの通知に対する反応
    //   - completionHandler: 処理完了を通知するコールバック
    // 戻り値: なし
    // 備考: 現時点では処理完了を通知するだけ。将来的に通知タップで特定画面へ遷移
    //       させたい場合はここに追加する。
    // =============================================================================
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // FCM dataペイロードを解析してアプリ内通知を発行
        if let type = userInfo["type"] as? String {
            var notificationData: [String: Any] = ["type": type]
            // 付加データを収集
            for key in ["post_id", "author_id", "liker_id", "follower_id", "date_key"] {
                if let value = userInfo[key] as? String {
                    notificationData[key] = value
                }
            }
            NotificationCenter.default.post(
                name: .notificationTapped,
                object: nil,
                userInfo: notificationData
            )
            print("[Push] Notification tapped: type=\(type), data=\(notificationData)")
        }
        
        // バッジをクリア
        UIApplication.shared.applicationIconBadgeNumber = 0
        
        completionHandler()
    }
}

// MARK: - Notification.Name Extension

extension Notification.Name {
    /// ユーザーがプッシュ通知をタップした時に発行される通知
    static let notificationTapped = Notification.Name("NotificationTapped")
}

// MARK: - MessagingDelegate
// 説明: Firebase Cloud Messaging（FCM）からのトークン更新イベントを受け取る

extension AppDelegate: MessagingDelegate {

    // =============================================================================
    // 【関数サマリー】messaging(_:didReceiveRegistrationToken:)
    // 目的: FCMトークンが発行・更新された際に、Firestoreのユーザードキュメントに保存する
    // 引数:
    //   - messaging: Messaging - Firebase Messagingインスタンス
    //   - fcmToken: String? - Firebaseが発行したプッシュ通知用トークン
    // 戻り値: なし
    // 処理の流れ:
    //   1. FCMトークンと現在ログイン中のユーザーIDを取得
    //   2. Firestoreのusers/{uid}ドキュメントにfcm_tokenフィールドを更新
    // 呼び出し元: Firebase Messaging（トークン発行時に自動呼び出し）
    // 備考: このトークンがないと、サーバーからこのユーザーへのプッシュ通知が送れない。
    // =============================================================================
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken,
              let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        Task {
            try? await Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["fcm_token": token])
        }
    }
}

