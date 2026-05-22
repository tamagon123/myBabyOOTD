import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 40)

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

                    // Features
                    VStack(spacing: 12) {
                        featureRow(icon: "🌡️", text: "気温・天気に合わせたコーデを検索")
                        featureRow(icon: "📸", text: "フロント・バック写真をセットで共有")
                        featureRow(icon: "🔒", text: "コメントなし・安心のSNS環境")
                    }
                    .padding(.horizontal, 24)

                    // Login / Register card
                    VStack(spacing: 0) {
                        // Tab
                        HStack(spacing: 0) {
                            tabButton(title: "ログイン", selected: isLoginMode) {
                                isLoginMode = true
                            }
                            tabButton(title: "新規登録", selected: !isLoginMode) {
                                isLoginMode = false
                            }
                        }
                        .padding(4)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)

                        VStack(spacing: 16) {
                            // Email
                            VStack(alignment: .leading, spacing: 6) {
                                Text("メールアドレス")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("example@mail.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Password
                            VStack(alignment: .leading, spacing: 6) {
                                Text("パスワード（6文字以上）")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("••••••••", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Confirm password (register only)
                            if !isLoginMode {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("パスワード（確認）")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    SecureField("••••••••", text: $confirmPassword)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            // Error
                            if let error = authViewModel.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }

                            // Action button
                            Button {
                                Task { await handleAction() }
                            } label: {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                } else {
                                    Text(isLoginMode ? "ログイン" : "アカウントを作成")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 50)
                                        .background(canSubmit ? Color.indigo : Color.gray)
                                        .cornerRadius(14)
                                }
                            }
                            .disabled(!canSubmit || authViewModel.isLoading)
                        }
                        .padding(24)
                    }
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
                    .padding(.horizontal, 20)

                    Text("利用することでプライバシーポリシーと利用規約に同意したことになります")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: isLoginMode) { _, _ in
            authViewModel.errorMessage = nil
            confirmPassword = ""
        }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        let emailOk = email.contains("@") && email.count > 4
        let passOk  = password.count >= 6
        if isLoginMode { return emailOk && passOk }
        return emailOk && passOk && confirmPassword == password
    }

    private func handleAction() async {
        if isLoginMode {
            await authViewModel.signInWithEmail(email: email, password: password)
        } else {
            await authViewModel.signUpWithEmail(email: email, password: password)
        }
    }

    @ViewBuilder
    private func tabButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? Color.white : Color.clear)
                .foregroundColor(selected ? .indigo : .secondary)
                .cornerRadius(10)
                .shadow(color: selected ? .black.opacity(0.06) : .clear, radius: 4)
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
