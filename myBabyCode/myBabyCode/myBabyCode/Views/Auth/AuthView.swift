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

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }

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
