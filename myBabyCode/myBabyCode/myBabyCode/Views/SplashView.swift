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
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .indigo.opacity(0.3), radius: 24, y: 10)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("Nanikiru")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, Color(red: 0.6, green: 0.3, blue: 1.0)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
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
