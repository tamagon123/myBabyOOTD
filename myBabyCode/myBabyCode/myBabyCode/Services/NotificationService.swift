// =============================================================================
// ファイル名: NotificationService.swift
// 役割: プッシュ通知の許可取得とFCMトークンのFirestore保存を管理
// 説明:
//   このファイルはiOSのプッシュ通知（リモート通知）に関する処理を担当します。
//   ユーザーに通知許可を求め、許可された場合にAppleのプッシュ通知サーバー（APNs）
//   へのデバイス登録を行います。また、Firebase Cloud Messaging（FCM）から発行される
//   トークンをFirestoreのユーザードキュメントに保存し、サーバーからのプッシュ通知
//   配信を可能にします。
// =============================================================================

import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth

final class NotificationService {
    // シングルトンインスタンス。アプリ全体で同一の通知サービスを共有。
    static let shared = NotificationService()
    private init() {}

    // =============================================================================
    // 【関数サマリー】requestPermissionIfNeeded
    // 目的: ユーザーにプッシュ通知の許可を求め、許可されていればリモート通知登録を行う
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. 現在の通知許可状態を取得（getNotificationSettings）
    //   2. 「未決定」の場合 → requestAuthorizationで許可ダイアログを表示
    //   3. ユーザーが「許可」または「仮許可」の場合 → registerForRemoteNotifications()
    //   4. 拒否済みの場合 → 何もしない
    // 呼び出し元: MainTabView.onAppear（アプリ起動後、メイン画面表示時）
    // 備考: registerForRemoteNotifications()はAPNsへのデバイス登録を行い、成功すると
    //       AppDelegateのdidRegisterForRemoteNotificationsWithDeviceTokenが呼ばれる。
    // =============================================================================
    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                // 初回: ユーザーに通知許可ダイアログを表示
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                ) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional:
                // 既に許可済み: デバイス登録のみ実施
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            default:
                // 拒否済みまたはその他: 何もしない
                break
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】saveFCMTokenIfSignedIn
    // 目的: ログイン中ユーザーのFCMトークンをFirestoreに保存する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. 現在ログイン中のFirebase Auth UIDを取得
    //   2. Firebase MessagingからFCMトークンを取得
    //   3. Firestoreのusers/{uid}ドキュメントにfcm_tokenフィールドを更新
    // 呼び出し元: MainTabView.onAppear（アプリ起動後）
    // 備考: FCMトークンはプッシュ通知を特定デバイスに送るための「宛先アドレス」に相当する。
    //       未ログイン時は何もしない。
    // =============================================================================
    func saveFCMTokenIfSignedIn() {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        Messaging.messaging().token { token, error in
            guard let token, error == nil else {
                if let error {
                    print("FCM token retrieval failed: \(error.localizedDescription)")
                }
                return
            }
            Task {
                do {
                    try await Firestore.firestore()
                        .collection("users")
                        .document(uid)
                        .updateData(["fcm_token": token])
                    print("FCM token saved successfully for user: \(uid)")
                } catch {
                    print("FCM token save failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
