import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.15), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("👶")
                    .font(.system(size: 80))
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 24, y: 10)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("今日のコーデ")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.indigo)
                    .opacity(opacity)

                ProgressView()
                    .tint(.indigo)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
