import SwiftUI

struct HomeView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var scrollToTopFlag = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // Header
                AppHeaderView(
                    onLogoTap: { scrollToTopFlag.toggle() },
                    showSearchButton: true
                )

                // Tab selector
                TimelineTabBar(selected: $postsViewModel.currentTab)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Feed
                if postsViewModel.isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if postsViewModel.posts.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("投稿がありません")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                Color.clear.frame(height: 0).id("homeTop")
                                ForEach(postsViewModel.posts, id: \.post_id) { post in
                                    PostCardView(
                                        post: post,
                                        isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                                        onLike: {
                                            Task { await postsViewModel.toggleLike(post: post) }
                                        },
                                        onReport: {
                                            Task { await postsViewModel.report(post: post) }
                                        }
                                    )
                                    .onAppear {
                                        if post.post_id == postsViewModel.posts.last?.post_id {
                                            Task { await postsViewModel.fetchMorePosts(user: authViewModel.currentUser) }
                                        }
                                    }
                                }
                                if postsViewModel.hasMorePosts {
                                    HStack { Spacer(); ProgressView(); Spacer() }
                                        .padding(.vertical, 12)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        }
                        .refreshable {
                            await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                            await postsViewModel.fetchLikedPosts()
                        }
                        .onChange(of: scrollToTopFlag) { _ in
                            withAnimation { proxy.scrollTo("homeTop") }
                        }
                    }
                }
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .task {
                await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                await postsViewModel.fetchLikedPosts()
            }
            .onChange(of: postsViewModel.currentTab) { _ in
                Task {
                    await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                }
            }
        }
    }
}

// MARK: - App Header

struct AppHeaderView: View {
    var onLogoTap: (() -> Void)? = nil
    var showSearchButton: Bool = true

    var body: some View {
        ZStack {
            Button {
                onLogoTap?()
            } label: {
                Text("Nanikiru")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.accentRed)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            if showSearchButton {
                HStack {
                    Spacer()
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.accentRed)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
                            .foregroundColor(selected == tab ? .accentRed : .gray)
                            .padding(.vertical, 8)
                        Rectangle()
                            .fill(selected == tab ? Color.accentRed : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.ecruBackground)
        .cornerRadius(12)
    }
}

