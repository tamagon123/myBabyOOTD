import SwiftUI
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn
import FirebaseCore

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUser: AppUser?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isLoading: Bool = false
    @Published var isInitializing: Bool = true

    @Published var autoLogin: Bool {
        didSet { UserDefaults.standard.set(autoLogin, forKey: "autoLogin") }
    }

    var needsProfileSetup: Bool {
        guard isSignedIn, let user = currentUser else { return false }
        return !(user.is_profile_complete ?? false)
    }

    private var currentNonce: String?
    private let db = Firestore.firestore()

    init() {
        self.autoLogin = UserDefaults.standard.object(forKey: "autoLogin") as? Bool ?? true
        Task { await initialize() }
    }

    private func initialize() async {
        await withCheckedContinuation { continuation in
            var resolved = false
            FirebaseAuth.Auth.auth().addStateDidChangeListener { _, user in
                guard !resolved else { return }
                resolved = true
                continuation.resume()
            }
        }
        let hasSession = FirebaseAuth.Auth.auth().currentUser != nil
        if hasSession && autoLogin {
            await loadCurrentUser()
            isSignedIn = true
        } else {
            if hasSession {
                try? FirebaseAuth.Auth.auth().signOut()
            }
            isSignedIn = false
        }
        isInitializing = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) {
        Task {
            isLoading = true
            do {
                let result = try await FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password)
                let uid = result.user.uid
                let docRef = db.collection("users").document(uid)
                let snapshot = try await docRef.getDocument()
                if !snapshot.exists {
                    // 新規ユーザー：最小限の情報のみ保存、プロファイル登録は別画面で完了
                    let newUser = AppUser(
                        user_id: uid,
                        unique_user_id: nil,
                        display_name: nil,
                        avatar_id: "bear",
                        avatar_bg_color: nil,
                        region_code: "13",
                        child_birthday: Date(),
                        child_gender: 0,
                        followers_count: 0,
                        children: nil,
                        is_profile_complete: false
                    )
                    try docRef.setData(from: newUser)
                    currentUser = newUser
                } else {
                    currentUser = try snapshot.data(as: AppUser.self)
                }
                isSignedIn = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func signUpWithEmail(email: String, password: String) {
        Task {
            isLoading = true
            do {
                let result = try await FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password)
                let uid = result.user.uid
                // 最小限の情報のみ保存、プロファイル登録は別画面で完了
                let newUser = AppUser(
                    user_id: uid,
                    unique_user_id: nil,
                    display_name: nil,
                    avatar_id: "bear",
                    avatar_bg_color: nil,
                    region_code: "13",
                    child_birthday: Date(),
                    child_gender: 0,
                    followers_count: 0,
                    children: nil,
                    is_profile_complete: false
                )
                try db.collection("users").document(uid).setData(from: newUser)
                currentUser = newUser
                isSignedIn = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func checkUniqueUserIdAvailable(_ uid: String) async -> Bool {
        do {
            let snapshot = try await db.collection("users")
                .whereField("unique_user_id", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()
            return snapshot.documents.isEmpty
        } catch {
            return true
        }
    }

    func reauthenticate(password: String) async -> Bool {
        guard let user = FirebaseAuth.Auth.auth().currentUser,
              let email = user.email else { return false }
        let credential = FirebaseAuth.EmailAuthProvider.credential(withEmail: email, password: password)
        do {
            try await user.reauthenticate(with: credential)
            return true
        } catch {
            errorMessage = "パスワードが正しくありません"
            return false
        }
    }

    func reauthenticateWithGoogle() async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return false }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Googleログインに失敗しました"
                return false
            }
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            guard let user = FirebaseAuth.Auth.auth().currentUser else { return false }
            try await user.reauthenticate(with: credential)
            return true
        } catch {
            errorMessage = "Googleログインに失敗しました"
            return false
        }
    }

    var isGoogleUser: Bool {
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "google.com" }
    }

    var isEmailUser: Bool {
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "password" }
    }

    func completeProfile(uniqueUserId: String, displayName: String, regionCode: String, avatarId: String?, avatarBgColor: String?, children: [ChildProfile]? = nil) async -> Bool {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "ログイン状態を確認できません"
            return false
        }
        // ユーザーIDの重複チェック
        if !uniqueUserId.isEmpty {
            let available = await checkUniqueUserIdAvailable(uniqueUserId)
            if !available {
                errorMessage = "そのユーザーIDは既に使われています"
                return false
            }
        }
        isLoading = true
        defer { isLoading = false }
        do {
            var updateData: [String: Any] = [
                "unique_user_id": uniqueUserId,
                "display_name": displayName,
                "region_code": regionCode,
                "avatar_id": avatarId ?? "bear",
                "avatar_bg_color": avatarBgColor as Any,
                "is_profile_complete": true
            ]
            // Add children if provided
            if let children = children, !children.isEmpty {
                let childrenData = children.map { [
                    "id": $0.id,
                    "name": $0.name,
                    "birthday": Timestamp(date: $0.birthday),
                    "gender": $0.gender
                ] }
                updateData["children"] = childrenData
            }
            try await db.collection("users").document(uid).updateData(updateData)
            // ローカル状態を更新
            currentUser?.unique_user_id = uniqueUserId
            currentUser?.display_name = displayName
            currentUser?.region_code = regionCode
            currentUser?.avatar_id = avatarId ?? "bear"
            currentUser?.avatar_bg_color = avatarBgColor
            currentUser?.is_profile_complete = true
            currentUser?.children = children
            return true
        } catch {
            errorMessage = "プロファイルの保存に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    func deleteAccount() async {
        guard let user = FirebaseAuth.Auth.auth().currentUser,
              let uid = currentUser?.user_id else {
            errorMessage = "ログイン状態を確認できません"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            // Delete user document from Firestore
            try await db.collection("users").document(uid).delete()
            // Delete posts by this user
            let postsSnapshot = try await db.collection("posts")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            for doc in postsSnapshot.documents {
                try? await doc.reference.delete()
            }
            // Delete likes by this user
            let likesSnapshot = try await db.collection("likes")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            for doc in likesSnapshot.documents {
                try? await doc.reference.delete()
            }
            // Delete follows
            let followsSnapshot = try await db.collection("follows")
                .whereField("follower_id", isEqualTo: uid)
                .getDocuments()
            for doc in followsSnapshot.documents {
                try? await doc.reference.delete()
            }
            let followingSnapshot = try await db.collection("follows")
                .whereField("following_id", isEqualTo: uid)
                .getDocuments()
            for doc in followingSnapshot.documents {
                try? await doc.reference.delete()
            }
            // Delete Firebase Auth user
            try await user.delete()
            isSignedIn = false
            currentUser = nil
        } catch let error as NSError {
            print("[DeleteAccount] Error: \(error.localizedDescription), code: \(error.code)")
            // FIRAuthErrorCodeRequiresRecentLogin = 17014
            if error.domain == "FIRAuthErrorDomain" && error.code == 17014 {
                errorMessage = "セキュリティのため、再度ログインしてから削除してください。"
            } else {
                errorMessage = "アカウントの削除に失敗しました: \(error.localizedDescription)"
            }
        } catch {
            print("[DeleteAccount] Unexpected error: \(error)")
            errorMessage = "アカウントの削除に失敗しました。再ログインしてお試しください。"
        }
    }

    // MARK: - Google Sign In

    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        Task {
            isLoading = true
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                guard let idToken = result.user.idToken?.tokenString else {
                    errorMessage = "Googleログインに失敗しました"
                    isLoading = false
                    return
                }
                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                let authResult = try await FirebaseAuth.Auth.auth().signIn(with: credential)
                let uid = authResult.user.uid
                let docRef = db.collection("users").document(uid)
                let snapshot = try await docRef.getDocument()
                if !snapshot.exists {
                    // 新規ユーザー：最小限の情報のみ保存、プロファイル登録は別画面で完了
                    let newUser = AppUser(
                        user_id: uid,
                        unique_user_id: nil,
                        display_name: nil,
                        avatar_id: "bear",
                        avatar_bg_color: nil,
                        region_code: "13",
                        child_birthday: Date(),
                        child_gender: 0,
                        followers_count: 0,
                        children: nil,
                        is_profile_complete: false
                    )
                    try docRef.setData(from: newUser)
                    currentUser = newUser
                } else {
                    currentUser = try snapshot.data(as: AppUser.self)
                }
                isSignedIn = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func resetPassword(email: String) {
        Task {
            isLoading = true
            successMessage = nil
            errorMessage = nil
            do {
                try await FirebaseAuth.Auth.auth().sendPasswordReset(withEmail: email)
                successMessage = "パスワードリセットメールを送信しました"
            } catch {
                errorMessage = "メール送信に失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - Apple Sign In

    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let auth):
            guard
                let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else { return }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            Task {
                isLoading = true
                do {
                    let result = try await FirebaseAuth.Auth.auth().signIn(with: credential)
                    let uid = result.user.uid
                    let docRef = db.collection("users").document(uid)
                    let snapshot = try await docRef.getDocument()
                    if !snapshot.exists {
                        // 新規ユーザー：最小限の情報のみ保存、プロファイル登録は別画面で完了
                        let newUser = AppUser(
                            user_id: uid,
                            unique_user_id: nil,
                            display_name: nil,
                            avatar_id: "bear",
                            avatar_bg_color: nil,
                            region_code: "13",
                            child_birthday: Date(),
                            child_gender: 0,
                            followers_count: 0,
                            children: nil,
                            is_profile_complete: false
                        )
                        try docRef.setData(from: newUser)
                        currentUser = newUser
                    } else {
                        currentUser = try snapshot.data(as: AppUser.self)
                    }
                    isSignedIn = true
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    func prepareSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    func signOut() {
        try? FirebaseAuth.Auth.auth().signOut()
        isSignedIn = false
        currentUser = nil
    }

    // MARK: - Load user

    func loadCurrentUser() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            currentUser = try doc.data(as: AppUser.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveUserProfile(_ user: AppUser) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveChildren(_ children: [ChildProfile]) async {
        guard var user = currentUser else { return }
        user.children = children
        await saveUserProfile(user)
    }

    func uploadAvatarImage(_ image: UIImage) async throws -> String {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { throw URLError(.badURL) }
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw URLError(.cannotDecodeContentData) }
        let ref = Storage.storage().reference().child("avatars/\(uid).jpg")
        _ = try await ref.putDataAsync(data)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Nonce helpers

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

