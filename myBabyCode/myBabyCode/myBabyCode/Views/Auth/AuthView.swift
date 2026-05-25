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

    // 計算プロパティ: メールとパスワードが空でないか（送信ボタンの有効化判定）
    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
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
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    // App icon
                    VStack(spacing: 14) {
                        Image("icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 20, y: 8)

                        Text("Nanikiru")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(.accentRed)

                        if authMode == .signUp {
                            Text("新規アカウントを作成")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Input fields
                    VStack(spacing: 14) {
                        inputField(placeholder: "メールアドレス", text: $email,
                                   contentType: .emailAddress, keyboard: .emailAddress)
                        inputField(placeholder: "パスワード", text: $password,
                                   contentType: .password, isSecure: true)

                        // Action button
                        Button(action: handleAuthAction) {
                            Group {
                                if authViewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(authMode == .login ? "ログイン" : "アカウントを作成")
                                        .font(.system(size: 17, weight: .bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.accentRed)
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

                        // Toggle auth mode
                        Button(action: {
                            authMode = authMode == .login ? .signUp : .login
                            authViewModel.errorMessage = nil
                            authViewModel.successMessage = nil
                        }) {
                            Text(authMode == .login ? "アカウントを作成する" : "既存アカウントでログイン")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentRed)
                        }

                        if authMode == .login {
                            Button(action: { showResetPassword = true }) {
                                Text("パスワードを忘れた場合")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
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
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(Color(red: 0.26, green: 0.52, blue: 0.96))
                            }
                            Text("Googleでサインイン")
                                .font(.system(size: 16, weight: .medium))
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

                    Toggle(isOn: $authViewModel.autoLogin) {
                        Text("次回から自動ログイン")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .tint(.accentRed)

                    Text("利用することでプライバシーポリシーと利用規約に同意したことになります")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 28)
            }
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
