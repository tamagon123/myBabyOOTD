import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

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

                // Sign in button
                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authViewModel.prepareSignInWithApple()
                    } onCompletion: { result in
                        authViewModel.handleSignInWithApple(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 54)
                    .cornerRadius(14)

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

                Text("利用することでプライバシーポリシーと利用規約に同意したことになります")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
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
