import SwiftUI
import FirebaseAuth
import Combine

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var postsViewModel = PostsViewModel()
    @State private var selectedTab: Int = 0
    @State private var showNewPost = false
    @State private var profileRefreshId = UUID()

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                switch selectedTab {
                case 0:
                    HomeView()
                        .environmentObject(postsViewModel)
                        .environmentObject(authViewModel)
                case 1:
                    SearchView()
                        .environmentObject(authViewModel)
                case 2:
                    ProfileView(userId: Auth.currentUID)
                        .environmentObject(authViewModel)
                        .id(profileRefreshId)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Ad banner space
            AdBannerView()

            // Bottom navigation
            BottomNavBar(
                selectedTab: $selectedTab,
                onPostTap: { showNewPost = true }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showNewPost, onDismiss: {
            profileRefreshId = UUID()
        }) {
            NewPostView()
                .environmentObject(postsViewModel)
                .environmentObject(authViewModel)
        }
    }
}

// MARK: - Bottom Nav Bar

struct BottomNavBar: View {
    @Binding var selectedTab: Int
    var onPostTap: () -> Void

    var body: some View {
        HStack {
            navItem(icon: "house.fill",   label: "ホーム",  tab: 0)
            Spacer()
            // Post button (center)
            Button(action: onPostTap) {
                ZStack {
                    Circle()
                        .fill(Color.indigo)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.indigo.opacity(0.4), radius: 8, y: 4)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.system(size: 24, weight: .bold))
                }
            }
            .offset(y: -12)
            Spacer()
            navItem(icon: "person.fill",  label: "マイページ", tab: 2)
        }
        .padding(.horizontal, 32)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        )
    }

    @ViewBuilder
    private func navItem(icon: String, label: String, tab: Int) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(selectedTab == tab ? .indigo : Color(.systemGray3))
        }
    }
}

// MARK: - Ad Banner View

struct AdBannerView: View {
    var body: some View {
        ZStack {
            Color(.systemGray6)
            Text("広告バナーエリア")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .overlay(
            Rectangle()
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
    }
}

// MARK: - Auth helper shim

enum Auth {
    static var currentUID: String {
        FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
    }
}

