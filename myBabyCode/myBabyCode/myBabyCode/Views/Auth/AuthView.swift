import SwiftUI
import AuthenticationServices

enum AuthMode {
    case login, signUp
}

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var authMode: AuthMode = .login
    @State private var showResetPassword: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.indigo.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App icon & title
                VStack(spacing: 16) {
                    Text("👶")
                        .font(.system(size: 72))
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 20, y: 8)

                    Text("今日のコーデ")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.indigo)

                    Text("赤ちゃんの服装を\n気温・天気でかんたん共有")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Features summary
                VStack(spacing: 12) {
                    featureRow(icon: "🌡️", text: "気温・天気に合わせたコーデを検索")
                    featureRow(icon: "📸", text: "フロント・バック写真をセットで共有")
                    featureRow(icon: "🔒", text: "コメントなし・安心のSNS環境")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Sign in section
                VStack(spacing: 16) {
                    // Email/Password fields
                    VStack(spacing: 12) {
                        TextField("メールアドレス", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)

                        SecureField("パスワード", text: $password)
                            .textContentType(.password)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
                    }

                    // Action button
                    Button(action: handleAuthAction) {
                        Text(authMode == .login ? "ログイン" : "新規登録")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.indigo)
                            .cornerRadius(14)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)

                    // Toggle auth mode
                    Button(action: { authMode = authMode == .login ? .signUp : .login }) {
                        Text(authMode == .login ? "アカウントを作成する" : "既存アカウントでログイン")
                            .font(.system(size: 14))
                            .foregroundColor(.indigo)
                    }

                    // Forgot password
                    if authMode == .login {
                        Button(action: { showResetPassword = true }) {
                            Text("パスワードを忘れた場合")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Divider
                    HStack {
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                        Text("または").font(.caption).foregroundColor(.secondary)
                        Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                    }

                    // Apple Sign In
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authViewModel.prepareSignInWithApple()
                    } onCompletion: { result in
                        authViewModel.handleSignInWithApple(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(14)

                    Toggle(isOn: $authViewModel.autoLogin) {
                        Text("次回から自動ログイン")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .tint(.indigo)
                    .padding(.horizontal, 4)

                    if authViewModel.isLoading {
                        ProgressView()
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .alert("パスワードリセット", isPresented: $showResetPassword) {
                    TextField("メールアドレス", text: $email)
                    Button("キャンセル", role: .cancel) {}
                    Button("送信") {
                        authViewModel.resetPassword(email: email)
                    }
                } message: {
                    Text("パスワードリセットメールを送信します")
                }

                Text("利用することでプライバシーポリシーと利用規約に同意したことになります")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
    }

    private func handleAuthAction() {
        switch authMode {
        case .login:
            authViewModel.signInWithEmail(email: email, password: password)
        case .signUp:
            authViewModel.signUpWithEmail(email: email, password: password)
        }
    }

    @ViewBuilder
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Text(icon).font(.title3)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
    }
}
