// =============================================================================
// ファイル名: AuthViewModel.swift
// 役割: ユーザー認証、アカウント管理、プロフィール操作を統括するViewModel
// 説明:
//   このクラスはアプリ内の「ユーザー認証に関するすべての処理」を担当します。
//   メール・Google・Appleの3種類のログイン方式をサポートし、Firestoreへの
//   ユーザー情報の読み書き、アバター画像のアップロード、アカウント削除なども
//   行います。SwiftUIの画面（View）と連携するため、@Publishedプロパティで
//   UIに変更を自動通知します。@MainActorにより、UI更新は必ずメインスレッドで
//   実行されます。
// =============================================================================

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
    // === UI状態通知用プロパティ ===
    // @Publishedを付けると値が変わるたびにSwiftUIのViewが自動で再描画される
    @Published var isSignedIn: Bool = false         // ログインしているか
    @Published var currentUser: AppUser?            // 現在のユーザーデータ
    @Published var errorMessage: String?            // エラーメッセージ（アラート表示用）
    @Published var successMessage: String?          // 成功メッセージ（トースト等）
    @Published var isLoading: Bool = false          // 処理中フラグ（ProgressView表示用）
    @Published var isInitializing: Bool = true      // アプリ起動時の初期化中フラグ

    // 自動ログイン設定。UserDefaultsに永続保存される。
    // didSet: 値が変更された瞬間にUserDefaultsに書き込む
    @Published var autoLogin: Bool {
        didSet { UserDefaults.standard.set(autoLogin, forKey: "autoLogin") }
    }

    // 計算プロパティ: ログイン済みかつプロフィール未完了ならtrue
    var needsProfileSetup: Bool {
        guard isSignedIn, let user = currentUser else { return false }
        return !(user.is_profile_complete ?? false)
    }

    // === プライベート状態 ===
    private var currentNonce: String?               // Appleサインインのnonce一時保持
    private let db = Firestore.firestore()          // Firestoreデータベース参照

    // =============================================================================
    // 【関数サマリー】init
    // 目的: ViewModel生成時に自動ログイン設定を読み込み、認証状態の初期化を開始する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. UserDefaultsからautoLogin設定を取得（未設定時はtrue=自動ログインON）
    //   2. バックグラウンドでinitialize()を非同期実行
    // =============================================================================
    init() {
        self.autoLogin = UserDefaults.standard.object(forKey: "autoLogin") as? Bool ?? true
        Task { await initialize() }
    }

    // =============================================================================
    // 【関数サマリー】initialize
    // 目的: アプリ起動時にFirebase Authの認証状態を確認し、画面遷移を決定する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebase Authの状態変化リスナーを1回だけ待機（初期状態確定までブロック）
    //   2. 現在のセッション有無を確認
    //   3. セッションあり＆自動ログインON → loadCurrentUser() → isSignedIn=true
    //   4. セッションあり＆自動ログインOFF → 強制サインアウト → isSignedIn=false
    //   5. セッションなし → isSignedIn=false
    //   6. isInitializing=falseでSplashView→次の画面へ遷移
    // 備考: privateなので外部から呼べず、init()内のTaskからのみ呼ばれる。
    // =============================================================================
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
    // 説明: メールアドレスとパスワードによる認証系処理

    // =============================================================================
    // 【関数サマリー】signInWithEmail
    // 目的: メールアドレスとパスワードでログインする
    // 引数:
    //   - email: String - ユーザーのメールアドレス
    //   - password: String - ユーザーのパスワード
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebase Auth.signIn()で認証
    //   2. 成功したらFirestoreのusers/{uid}を取得
    //   3. ドキュメントが存在しない（新規ユーザーのメール登録後初回ログイン等）→
    //      最小限のAppUserを新規作成してFirestoreに保存
    //   4. 既存 → currentUserに読み込み
    //   5. isSignedIn=trueでメイン画面へ遷移
    // 呼び出し元: AuthView.handleAuthAction()
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】signUpWithEmail
    // 目的: メールアドレスとパスワードで新規アカウントを作成する
    // 引数:
    //   - email: String - 新規ユーザーのメールアドレス
    //   - password: String - 設定するパスワード
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebase Auth.createUser()でアカウント作成
    //   2. 成功したらFirestoreに最小限のAppUserを新規保存
    //   3. currentUserにセットしisSignedIn=true
    // 呼び出し元: AuthView.handleAuthAction()（authMode == .signUp時）
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】checkUniqueUserIdAvailable
    // 目的: 指定したユーザーID（unique_user_id）が他のユーザーと重複していないか確認する
    // 引数:
    //   - uid: String - 確認したいユーザーID文字列
    // 戻り値: Bool - true=未使用（利用可能）、false=既に存在
    // 処理の流れ:
    //   1. Firestore usersコレクションでunique_user_id==uidのドキュメントを検索
    //   2. 結果が空なら未使用 → true
    //   3. エラー発生時は安全側に倒してtrueを返す（保存時に再度チェックされる）
    // 呼び出し元: completeProfile(), ProfileSetupViewのID入力時
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】reauthenticate
    // 目的: センシティブ操作（アカウント削除等）前に、メールユーザーのパスワードで再認証する
    // 引数:
    //   - password: String - 現在のパスワード
    // 戻り値: Bool - true=再認証成功、false=失敗
    // 処理の流れ:
    //   1. 現在のFirebase Authユーザーとメールアドレスを取得
    //   2. EmailAuthProvider.credential()で認証情報を作成
    //   3. user.reauthenticate()でFirebaseに再認証を要求
    //   4. 失敗時はerrorMessageに「パスワードが正しくありません」をセット
    // 呼び出し元: SettingsView（アカウント削除前の再認証ダイアログ）
    // 備考: Firebase Authは削除などの重要操作を行う前に「最近ログインした」ことを
    //       要求するため、この再認証が必要となる。
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】reauthenticateWithGoogle
    // 目的: Google認証ユーザーの再認証を、Googleサインインフローで実行する
    // 引数: なし
    // 戻り値: Bool - true=再認証成功、false=失敗
    // 処理の流れ:
    //   1. FirebaseのclientIDからGIDConfigurationを作成
    //   2. 現在の画面（rootViewController）を取得
    //   3. GIDSignIn.signIn()でGoogleログインフローを表示
    //   4. 取得したidTokenとaccessTokenからGoogleAuthProvider.credentialを作成
    //   5. user.reauthenticate()でFirebaseに再認証
    // 呼び出し元: SettingsView（Google認証ユーザーのアカウント削除前）
    // =============================================================================
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

    // 計算プロパティ: 現在のユーザーがGoogle認証かどうか
    var isGoogleUser: Bool {
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "google.com" }
    }

    // 計算プロパティ: 現在のユーザーがメール・パスワード認証かどうか
    var isEmailUser: Bool {
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return false }
        return user.providerData.contains { $0.providerID == "password" }
    }

    // =============================================================================
    // 【関数サマリー】completeProfile
    // 目的: 初回プロフィール設定画面で入力された情報をFirestoreに保存し、登録を完了させる
    // 引数:
    //   - uniqueUserId: String - ユーザーが設定した一意の表示ID
    //   - displayName: String - 画面に表示される名前
    //   - regionCode: String - 都道府県コード（2桁）
    //   - avatarId: String? - アバター画像URL/名前/絵文字
    //   - avatarBgColor: String? - アバター背景色（HEX文字列）
    //   - children: [ChildProfile]? - 子供のプロフィール配列（任意）
    // 戻り値: Bool - true=保存成功、false=失敗（重複エラー等）
    // 処理の流れ:
    //   1. ユーザーIDの重複チェック（空文字はスキップ）
    //   2. Firestore users/{uid} に updateData でプロフィール情報を更新
    //   3. 子供情報があればchildrenフィールドとして追加
    //   4. ローカルのcurrentUserも同時に更新（UI即反映）
    // 呼び出し元: ProfileSetupView.completeProfile()
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】deleteAccount
    // 目的: ユーザーのアカウントを完全に削除する（Firestoreデータ + Authアカウント）
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firestoreのusers/{uid}ドキュメントを削除
    //   2. このユーザーのposts（投稿）をすべて削除
    //   3. このユーザーのlikes（いいね履歴）をすべて削除
    //   4. このユーザーのfollows（フォロー関係）をすべて削除
    //   5. Firebase Authのアカウントを削除
    //   6. isSignedIn=falseでログイン画面へ遷移
    // 呼び出し元: SettingsView（アカウント削除確認後）
    // 備考: セキュリティ上、Firebase Authは「最近ログインしていない」場合に
    //       エラーコード17014を返す。その場合は再認証を促すメッセージを表示する。
    // =============================================================================
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
    // 説明: Googleアカウントを利用したOAuth認証フロー

    // =============================================================================
    // 【関数サマリー】signInWithGoogle
    // 目的: Googleアカウントでログイン・新規登録を行う
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. FirebaseのclientIDからGIDConfigurationを作成
    //   2. 現在の画面（rootViewController）を取得
    //   3. GIDSignIn.signIn()でGoogleの認証フローを開始
    //   4. 取得したidTokenとaccessTokenからGoogleAuthProvider.credentialを作成
    //   5. Firebase Auth.signIn(with:)でFirebase認証
    //   6. 新規ユーザー → Firestoreに最小限のAppUserを作成
    //   7. 既存ユーザー → FirestoreからcurrentUserを読み込み
    //   8. isSignedIn=trueでメイン画面へ遷移
    // 呼び出し元: AuthView（Googleサインボタンタップ時）
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】resetPassword
    // 目的: パスワードを忘れたユーザーに、パスワードリセットメールを送信する
    // 引数:
    //   - email: String - リセット先のメールアドレス
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebase Auth.sendPasswordReset(withEmail:)でリセットメール送信
    //   2. 成功 → successMessageに「パスワードリセットメールを送信しました」
    //   3. 失敗 → errorMessageにエラー詳細をセット
    // 呼び出し元: AuthView（パスワードを忘れた方はこちらボタン）
    // =============================================================================
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
    // 説明: Apple IDを利用したOAuth認証フロー（Sign in with Apple）

    // =============================================================================
    // 【関数サマリー】handleSignInWithApple
    // 目的: Sign in with Appleの認証結果を受け取り、Firebase Authでログインする
    // 引数:
    //   - result: Result<ASAuthorization, Error> - Appleの認証結果（成功または失敗）
    // 戻り値: なし
    // 処理の流れ:
    //   1. 失敗時 → errorMessageにエラー詳細をセット
    //   2. 成功時 → ASAuthorizationAppleIDCredentialからidentityTokenを取得
    //   3. prepareSignInWithApple()で生成したnonceと組み合わせてcredential作成
    //   4. Firebase Auth.signIn(with:)でFirebase認証
    //   5. 新規ユーザー → Firestoreに最小限のAppUserを作成
    //   6. 既存ユーザー → FirestoreからcurrentUserを読み込み
    //   7. isSignedIn=trueでメイン画面へ遷移
    // 呼び出し元: AuthView（SignInWithAppleButtonのcompletionハンドラ）
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】prepareSignInWithApple
    // 目的: Appleサインイン前に、セキュリティ用のnonceを生成・ハッシュ化する
    // 引数: なし
    // 戻り値: String - SHA256ハッシュ化されたnonce文字列。SignInWithAppleButtonに渡す。
    // 処理の流れ:
    //   1. randomNonceString()で32文字のランダム文字列を生成
    //   2. currentNonceに生のnonceを保持（handleSignInWithAppleで検証用）
    //   3. sha256()でハッシュ化し、Appleに送信するnonceとして返却
    // 呼び出し元: AuthView（SignInWithAppleButton表示前）
    // 備考: nonceは「リプレイ攻撃」を防ぐための必須セキュリティ仕様。
    // =============================================================================
    func prepareSignInWithApple() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }

    // =============================================================================
    // 【関数サマリー】signOut
    // 目的: 現在のユーザーをログアウトさせる
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. Firebase Auth.signOut()でセッションを破棄
    //   2. isSignedIn=false, currentUser=nil でログイン画面へ遷移
    // 呼び出し元: SettingsView（ログアウト確認後）
    // =============================================================================
    func signOut() {
        try? FirebaseAuth.Auth.auth().signOut()
        isSignedIn = false
        currentUser = nil
    }

    // MARK: - Load user
    // 説明: Firestoreから現在のユーザードキュメントを読み込む系処理

    // =============================================================================
    // 【関数サマリー】loadCurrentUser
    // 目的: Firebase AuthのUIDに対応するFirestoreユーザードキュメントを取得する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. 現在ログイン中のFirebase Auth UIDを取得
    //   2. Firestore users/{uid}.getDocument() でデータ取得
    //   3. AppUser型にデコードして currentUser にセット
    // 呼び出し元: initialize(), signInWithEmail(), signInWithGoogle(), handleSignInWithApple()
    // =============================================================================
    func loadCurrentUser() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            currentUser = try doc.data(as: AppUser.self)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // =============================================================================
    // 【関数サマリー】saveUserProfile
    // 目的: 変更されたユーザープロフィールをFirestoreに保存する
    // 引数:
    //   - user: AppUser - 保存するユーザーデータ
    // 戻り値: なし
    // 処理の流れ:
    //   1. 現在ログイン中のUIDを取得
    //   2. Firestore users/{uid}.setData(from: merge: true) で保存
    //      merge: true は既存フィールドを上書きせず、差分のみ更新する
    //   3. currentUserを更新したuserに置き換え
    // 呼び出し元: EditProfileView.save(), saveChildren()
    // =============================================================================
    func saveUserProfile(_ user: AppUser) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            try db.collection("users").document(uid).setData(from: user, merge: true)
            currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // =============================================================================
    // 【関数サマリー】saveChildren
    // 目的: 子供のプロフィール配列を更新し、Firestoreに保存する
    // 引数:
    //   - children: [ChildProfile] - 更新後の子供プロフィール配列
    // 戻り値: なし
    // 処理の流れ:
    //   1. currentUser.childrenに新しい配列をセット
    //   2. saveUserProfile()を呼び出してFirestoreに反映
    // 呼び出し元: EditProfileView（子供情報の追加・編集・削除時）
    // =============================================================================
    func saveChildren(_ children: [ChildProfile]) async {
        guard var user = currentUser else { return }
        user.children = children
        await saveUserProfile(user)
    }

    // =============================================================================
    // 【関数サマリー】uploadAvatarImage
    // 目的: ライブラリから選択したアバター画像をFirebase Storageにアップロードする
    // 引数:
    //   - image: UIImage - アップロードする画像データ
    // 戻り値: String - アップロード後のダウンロードURL文字列
    // 処理の流れ:
    //   1. 画像をJPEG形式で圧縮（品質80%）
    //   2. Storageの avatars/{uid}.jpg パスにアップロード
    //   3. ダウンロードURLを取得して返却
    // 呼び出し元: EditProfileView（アバター画像をライブラリから選択後）
    // 備考: 同じUIDでアップロードすると、既存の画像が上書きされる。
    // =============================================================================
    func uploadAvatarImage(_ image: UIImage) async throws -> String {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { throw URLError(.badURL) }
        guard let data = image.jpegData(compressionQuality: 0.8) else { throw URLError(.cannotDecodeContentData) }
        let ref = Storage.storage().reference().child("avatars/\(uid).jpg")
        _ = try await ref.putDataAsync(data)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Nonce helpers
    // 説明: Appleサインインに必要なセキュリティnonceの生成・ハッシュ化ユーティリティ

    // =============================================================================
    // 【関数サマリー】randomNonceString
    // 目的: Appleサインイン用の安全なランダム文字列（nonce）を生成する
    // 引数:
    //   - length: Int - 生成する文字列の長さ。デフォルト32文字。
    // 戻り値: String - ランダムな英数字と記号からなるnonce文字列
    // 処理の流れ:
    //   1. SecRandomCopyBytesで暗号的に安全な乱数を生成
    //   2. 指定文字セット（charset）からランダムに文字を選択して結合
    // 呼び出し元: prepareSignInWithApple()
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】sha256
    // 目的: 文字列をSHA-256ハッシュ化する
    // 引数:
    //   - input: String - ハッシュ化元の文字列（nonceの生値）
    // 戻り値: String - 16進数表記の64文字ハッシュ値
    // 処理の流れ:
    //   1. UTF-8エンコードでData型に変換
    //   2. CryptoKitのSHA256.hashでハッシュ計算
    //   3. 各バイトを2桁16進数文字列に変換して結合
    // 呼び出し元: prepareSignInWithApple()
    // 備考: Appleはnonceを平文で送信せず、ハッシュ化された値を要求する。
    // =============================================================================
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

