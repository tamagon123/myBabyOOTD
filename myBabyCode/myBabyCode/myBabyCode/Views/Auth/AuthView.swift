// =============================================================================
// ファイル名: AuthView.swift
// 役割: ログイン・新規登録画面（メール / Apple / Google対応）
// 説明:
//   未ログイン時に表示される認証画面です。メールアドレスとパスワードによる
//   ログイン・新規登録、Sign in with Apple、Google Sign-Inの3種類の認証方式を
//   提供します。AuthViewModelと連携し、認証成功時に自動でメイン画面へ遷移します。
// =============================================================================

import SwiftUI
import AuthenticationServices

// AuthMode: 画面が「ログイン」モードか「新規登録」モードかを表す列挙型
enum AuthMode {
    case login, signUp
}

struct AuthView: View {
    // === 環境・状態 ===
    @EnvironmentObject var authViewModel: AuthViewModel  // 認証処理をViewModelに委譲
    @State private var email: String = ""                  // メールアドレス入力値
    @State private var password: String = ""               // パスワード入力値
    @State private var authMode: AuthMode = .login       // 現在のモード（ログイン/新規登録）
    @State private var showResetPassword: Bool = false   // パスワードリセットアラートの表示状態
    @State private var agreedToTerms: Bool = false       // 利用規約同意チェックボックス状態
    @State private var showTerms: Bool = false           // 利用規約シート表示フラグ
    @State private var showPrivacy: Bool = false         // プライバシーポリシーシート表示フラグ

    // 計算プロパティ: メールとパスワードが空でないか＋新規登録時は利用規約同意必須
    private var canSubmit: Bool {
        guard !email.isEmpty && !password.isEmpty else { return false }
        if authMode == .signUp { return agreedToTerms }
        return true
    }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 認証画面の全体レイアウトを定義
    // 構成:
    //   1. 背景: 生成り色（ecruBackground）
    //   2. ScrollView内にVStackで縦積み:
    //      - アプリアイコン＋アプリ名
    //      - メール・パスワード入力フィールド＋アクションボタン
    //      - エラー/成功メッセージ
    //      - モード切替ボタン（ログイン↔新規登録）
    //      - パスワードリセットリンク（ログイン時のみ）
    //      - 「または」区切り線
    //      - Apple Sign Inボタン
    //      - Google Sign Inボタン
    //      - 自動ログイントグル
    //      - 利用規約同意テキスト
    //   3. パスワードリセット用アラート
    // =============================================================================
    var body: some View {
        ZStack {
            Color.ecruBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 20)

                    // App logo
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)

                    // ─── ログイン / 新規登録 タブ ───
                    HStack(spacing: 0) {
                        tabButton(title: "ログイン", mode: .login)
                        tabButton(title: "新規登録", mode: .signUp)
                    }
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    .padding(.horizontal, 4)

                    // Input fields + action
                    VStack(spacing: 14) {
                        inputField(placeholder: "メールアドレス", text: $email,
                                   contentType: .emailAddress, keyboard: .emailAddress)
                        inputField(placeholder: "パスワード", text: $password,
                                   contentType: .password, isSecure: true)

                        if authMode == .login {
                            HStack {
                                Spacer()
                                Button(action: { showResetPassword = true }) {
                                    Text("パスワードを忘れた場合")
                                        .font(.appFont(.regular, size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // 利用規約チェック（新規登録時・ボタン上部）
                        if authMode == .signUp {
                            HStack(alignment: .top, spacing: 10) {
                                Button {
                                    agreedToTerms.toggle()
                                } label: {
                                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                                        .font(.appFont(.regular, size: 20))
                                        .foregroundColor(agreedToTerms ? .accentRed : .secondary)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 0) {
                                        Button { showTerms = true } label: {
                                            Text("利用規約")
                                                .font(.appFont(.medium, size: 12))
                                                .foregroundColor(.accentRed)
                                                .underline()
                                        }
                                        .buttonStyle(.plain)
                                        Text("および")
                                            .font(.appFont(.medium, size: 12))
                                            .foregroundColor(.secondary)
                                        Button { showPrivacy = true } label: {
                                            Text("プライバシーポリシー")
                                                .font(.appFont(.regular, size: 12))
                                                .foregroundColor(.accentRed)
                                                .underline()
                                        }
                                        .buttonStyle(.plain)
                                        Text("に同意します")
                                            .font(.appFont(.regular, size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Text("アカウント作成には同意が必要です")
                                        .font(.appFont(.regular, size: 10))
                                        .foregroundColor(agreedToTerms ? .clear : .red.opacity(0.8))
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // Action button
                        Button(action: handleAuthAction) {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(authMode == .login ? "ログイン" : "アカウントを作成")
                                        .font(.appFont(.bold, size: 17))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(canSubmit ? Color.accentRed : Color.secondary.opacity(0.4))
                            .cornerRadius(16)
                        }
                        .disabled(!canSubmit || authViewModel.isLoading)

                        if let error = authViewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        if let success = authViewModel.successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.2))
                        Text("または").font(.caption).foregroundColor(.secondary).fixedSize()
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.2))
                    }

                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authViewModel.prepareSignInWithApple()
                    } onCompletion: { result in
                        authViewModel.handleSignInWithApple(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(14)

                    // Google Sign In
                    Button(action: { authViewModel.signInWithGoogle() }) {
                        HStack(spacing: 10) {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(0.85)
                                    .tint(Color(red: 0.26, green: 0.52, blue: 0.96))
                            } else {
                                Image(systemName: "globe")
                                    .font(.appFont(.medium, size: 18))
                                    .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                            }
                            Text("Googleでサインイン")
                                .font(.appFont(.medium, size: 16))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                    }
                    .disabled(authViewModel.isLoading)

                    // Guest login
                    Button(action: { Task { await authViewModel.signInAsGuest() } }) {
                        Text("ゲストとして利用する（登録不要）")
                            .font(.appFont(.medium, size: 14))
                            .foregroundColor(Color(.label))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(.systemGray5))
                            .cornerRadius(14)
                    }

                    Toggle(isOn: $authViewModel.autoLogin) {
                        Text("次回から自動ログイン")
                            .font(.appFont(.medium, size: 14))
                            .foregroundColor(.secondary)
                    }
                    .tint(.accentRed)

                    HStack(spacing: 0) {
                        Text("利用することで")
                            .font(.appFont(.regular, size: 10))
                            .foregroundColor(.secondary)
                        Button { showPrivacy = true } label: {
                            Text("プライバシーポリシー")
                                .font(.appFont(.regular, size: 10))
                                .foregroundColor(.accentRed)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        Text("と")
                            .font(.appFont(.medium, size: 10))
                            .foregroundColor(.secondary)
                        Button { showTerms = true } label: {
                            Text("利用規約")
                                .font(.appFont(.regular, size: 10))
                                .foregroundColor(.accentRed)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        Text("に同意したことになります")
                            .font(.appFont(.regular, size: 10))
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 28)
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationView {
                TermsOfServiceView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .sheet(isPresented: $showPrivacy) {
            NavigationView {
                PrivacyPolicyView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .alert("パスワードリセット", isPresented: $showResetPassword) {
            TextField("メールアドレス", text: $email)
            Button("キャンセル", role: .cancel) {}
            Button("送信") {
                authViewModel.resetPassword(email: email)
            }
        } message: {
            Text("パスワードリセットメールを送信します")
        }
    }

    // =============================================================================
    // 【関数サマリー】handleAuthAction
    // 目的: ログインボタンまたは新規登録ボタンタップ時の処理を振り分ける
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. エラー・成功メッセージをクリア
    //   2. authModeに応じてViewModelのsignInWithEmail()またはsignUpWithEmail()を呼び出し
    // 呼び出し元: body内の「ログイン」/「アカウントを作成」ボタン
    // =============================================================================
    @ViewBuilder
    private func tabButton(title: String, mode: AuthMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                authMode = mode
                authViewModel.errorMessage = nil
                authViewModel.successMessage = nil
            }
        } label: {
            Text(title)
                .font(.appFont(.bold, size: 15))
                .foregroundColor(authMode == mode ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    authMode == mode ? Color.accentRed : Color.clear
                )
                .cornerRadius(10)
                .padding(3)
        }
        .buttonStyle(.plain)
    }

    private func handleAuthAction() {
        authViewModel.errorMessage = nil
        authViewModel.successMessage = nil
        switch authMode {
        case .login:
            authViewModel.signInWithEmail(email: email, password: password)
        case .signUp:
            authViewModel.signUpWithEmail(email: email, password: password)
        }
    }

    // =============================================================================
    // 【Viewサマリー】inputField
    // 目的: テキスト入力フィールド（TextField / SecureField）を生成する汎用ヘルパー
    // 引数:
    //   - placeholder: String - 入力欄のプレースホルダー文字列
    //   - text: Binding<String> - 入力値を双方向バインディングするState
    //   - contentType: UITextContentType - iOS自動入力の種類（.emailAddress / .passwordなど）
    //   - keyboard: UIKeyboardType - 表示するキーボードタイプ
    //   - isSecure: Bool - true=SecureField（マスク表示）、false=通常TextField
    // 戻り値: some View
    // =============================================================================
    @ViewBuilder
    private func inputField(placeholder: String, text: Binding<String>,
                            contentType: UITextContentType, keyboard: UIKeyboardType = .default,
                            isSecure: Bool = false) -> some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: text)
                    .textContentType(contentType)
            } else {
                TextField(placeholder, text: text)
                    .textContentType(contentType)
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
    }
}
