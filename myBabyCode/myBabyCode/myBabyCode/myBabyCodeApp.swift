import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging

@main
struct myBabyCodeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 100 * 1024 * 1024
        Firestore.firestore().settings = settings
    }

    var body: some Scene {
        WindowGroup {
            if authViewModel.isInitializing {
                SplashView()
            } else if authViewModel.isSignedIn {
                if authViewModel.needsProfileSetup {
                    ProfileSetupView()
                        .environmentObject(authViewModel)
                } else {
                    MainTabView()
                        .environmentObject(authViewModel)
                }
            } else {
                AuthView()
                    .environmentObject(authViewModel)
            }
        }
    }
}
