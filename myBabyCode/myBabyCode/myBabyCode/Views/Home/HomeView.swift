import SwiftUI

struct HomeView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                AppHeaderView(showSearch: $showSearch)

                // Tab selector
                TimelineTabBar(selected: $postsViewModel.currentTab)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Feed
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if postsViewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if postsViewModel.posts.isEmpty {
                            VStack(spacing: 12) {
                                Text("👶").font(.system(size: 48))
                                Text("投稿がありません").foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            ForEach(postsViewModel.posts) { post in
                                PostCardView(
                                    post: post,
                                    isLiked: postsViewModel.likedPostIds.contains(post.id ?? ""),
                                    onLike: {
                                        Task { await postsViewModel.toggleLike(post: post) }
                                    },
                                    onReport: {
                                        Task { await postsViewModel.report(post: post) }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .refreshable {
                    await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                    await postsViewModel.fetchLikedPosts()
                }
            }
            .navigationBarHidden(true)
            .task {
                await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                await postsViewModel.fetchLikedPosts()
            }
            .onChange(of: postsViewModel.currentTab) { _, _ in
                Task {
                    await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                }
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

// MARK: - App Header

struct AppHeaderView: View {
    @Binding var showSearch: Bool

    var body: some View {
        HStack {
            Text("👶")
                .font(.system(size: 28))
            Spacer()
            Text("今日のコーデ")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.indigo)
            Spacer()
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20))
                    .foregroundColor(.indigo)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
    }
}

// MARK: - Timeline Tab Bar

struct TimelineTabBar: View {
    @Binding var selected: TimelineTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimelineTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selected == tab ? .bold : .regular))
                            .foregroundColor(selected == tab ? .indigo : .gray)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(selected == tab ? Color.indigo : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
    }
}
