import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseFirestore
import FirebaseAuth

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                ) { granted, _ in
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            default:
                break
            }
        }
    }

    func saveFCMTokenIfSignedIn() {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        Messaging.messaging().token { token, error in
            guard let token, error == nil else { return }
            Task {
                try? await Firestore.firestore()
                    .collection("users")
                    .document(uid)
                    .updateData(["fcm_token": token])
            }
        }
    }
}
