import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.ecruBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.10), radius: 24, y: 10)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("Nanikiru")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.accentRed)
                    .opacity(opacity)

                ProgressView()
                    .tint(.accentRed)
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
