import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// NOTE: リリース時に Apple Sign In へ移行予定
// 移行手順は セットアップ手順書.md の STEP 4 を参照

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var currentUser: AppUser?
    @Published var children: [Child] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let db = Firestore.firestore()

    init() {
        isSignedIn = FirebaseAuth.Auth.auth().currentUser != nil
        if isSignedIn {
            Task {
                await loadCurrentUser()
                await loadChildren()
            }
        }
    }

    // MARK: - Email Sign Up

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            let newUser = AppUser(
                user_id: uid,
                display_name: "",
                avatar_id: "🐶",
                region_code: "13",
                child_birthday: Date(),
                child_gender: 0,
                followers_count: 0
            )
            try await db.collection("users").document(uid).setData(from: newUser)
            currentUser = newUser
            isSignedIn = true
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
        isLoading = false
    }

    // MARK: - Email Sign In

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password)
            let uid = result.user.uid
            let doc = try await db.collection("users").document(uid).getDocument()
            if doc.exists {
                currentUser = try doc.data(as: AppUser.self)
            } else {
                let newUser = AppUser(
                    user_id: uid,
                    display_name: "",
                    avatar_id: "🐶",
                    region_code: "13",
                    child_birthday: Date(),
                    child_gender: 0,
                    followers_count: 0
                )
                try await db.collection("users").document(uid).setData(from: newUser)
                currentUser = newUser
            }
            await loadChildren()
            isSignedIn = true
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
        isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        try? FirebaseAuth.Auth.auth().signOut()
        isSignedIn = false
        currentUser = nil
        children = []
    }

    // MARK: - Children

    func loadChildren() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("children")
                .order(by: "sort_order")
                .getDocuments()
            children = try snap.documents.map { try $0.data(as: Child.self) }
        } catch {
            errorMessage = "子供情報の読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    func addChild(_ child: Child) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "ログインセッションが切れています。再ログインしてください。"
            return
        }
        do {
            let ref = db.collection("users").document(uid)
                .collection("children").document(child.child_id)
            try await ref.setData(from: child)
            children.append(child)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateChild(_ child: Child) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "ログインセッションが切れています。再ログインしてください。"
            return
        }
        do {
            let ref = db.collection("users").document(uid)
                .collection("children").document(child.child_id)
            try await ref.setData(from: child)
            if let idx = children.firstIndex(where: { $0.child_id == child.child_id }) {
                children[idx] = child
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteChild(_ child: Child) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "ログインセッションが切れています。再ログインしてください。"
            return
        }
        do {
            try await db.collection("users").document(uid)
                .collection("children").document(child.child_id).delete()
            children.removeAll { $0.child_id == child.child_id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load / Save user

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
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else {
            errorMessage = "ログインセッションが切れています。再ログインしてください。"
            return
        }
        do {
            try await db.collection("users").document(uid).setData(from: user, merge: true)
            currentUser = user
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Error message（日本語化）

    private func firebaseErrorMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17007: return "このメールアドレスはすでに登録されています。"
        case 17008: return "メールアドレスの形式が正しくありません。"
        case 17009: return "パスワードが間違っています。"
        case 17011: return "このメールアドレスは登録されていません。"
        case 17026: return "パスワードは6文字以上で設定してください。"
        default:    return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
}

