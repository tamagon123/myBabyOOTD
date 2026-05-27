// =============================================================================
// ファイル名: ProfileView.swift
// 役割: ユーザープロフィール画面（自分・他ユーザーの投稿一覧・いいね一覧・フォロー）
// 説明:
//   マイページや他ユーザーのプロフィールを表示する画面です。
//   アバター・表示名・子供情報、投稿件数、フォロー/フォロワー数をヘッダーに表示し、
//   下部には「投稿」タブ（自分の投稿グリッド）と「いいね」タブ（いいねした投稿）を
//   切り替えて表示します。他ユーザーのプロフィールの場合はフォローボタンが表示されます。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    // === 入力パラメータ ===
    let userId: String  // 表示対象のユーザーUID（自分または他ユーザー）

    // === 環境オブジェクト ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var draftManager: DraftManager

    // === 状態 ===
    @State private var profileUser: AppUser?          // プロフィールユーザーのデータ
    @State private var userPosts: [Post] = []        // このユーザーの投稿一覧
    @State private var likedPosts: [Post] = []        // 自分がいいねした投稿一覧
    @State private var isLoading = false             // 読み込み中フラグ
    @State private var isFollowing = false            // フォロー済みフラグ（他ユーザーの場合）
    @State private var errorMessage: String? = nil   // エラーメッセージ
    @State private var showEditProfile = false        // プロフィール編集シート表示フラグ
    @State private var showSettings = false           // 設定画面表示フラグ
    @State private var selectedPost: Post? = nil     // タップされた投稿（詳細画面へ）
    @State private var selectedTab: ProfileTab = .posts  // 選択中のタブ（投稿/いいね）
    @State private var showFollowingList = false       // フォロー一覧表示フラグ
    @State private var followingUsers: [AppUser] = [] // フォロー中のユーザーリスト
    @State private var followingCount: Int = 0         // フォロー中の件数
    @State private var isGridMode: Bool = false        // グリッド/リスト表示モード

    // ProfileTab: マイページ内の「投稿」/「いいね」タブ
    enum ProfileTab: String, CaseIterable {
        case posts = "投稿"
        case likes = "いいね"
    }

    // === プライベート ===
    private let db = Firestore.firestore()
    // 計算プロパティ: 自分のプロフィールかどうか
    private var isOwnProfile: Bool { userId == FirebaseAuth.Auth.auth().currentUser?.uid }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: プロフィール画面の全体レイアウトを定義
    // 構成:
    //   1. ヘッダー: アバター・名前・子供情報・投稿数・フォロー/フォロワー数
    //   2. タブセレクター（自分のプロフィール時のみ: 投稿/いいね）
    //   3. 投稿グリッド（LazyVGridで2列表示）またはいいね一覧
    //   4. 右上: 設定ボタン（自分のプロフィール時のみ）
    // =============================================================================
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // プロフィールヘッダー
                profileHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // タブセレクター（自分のプロフィール時のみ）
                if isOwnProfile {
                    tabSelector
                }

                // 投稿グリッドまたはいいね一覧
                if isLoading {
                    ProgressView().padding()
                } else {
                    if selectedTab == .posts {
                        postsGrid
                    } else {
                        likedPostsGrid
                    }
                }
            }
        }
        .background(Color.ecruBackground.ignoresSafeArea())
        // 右上に設定ボタン（自分のプロフィール時のみ）
        .overlay(alignment: .topTrailing) {
            if isOwnProfile {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(16)
                }
            }
        }
        // Pull-to-refresh
        .refreshable {
            await loadProfile()
            await loadUserPosts()
            if isOwnProfile { await loadLikedPosts() }
            if !isOwnProfile { await checkFollowing() }
        }
        // 画面表示時にデータ取得
        .task {
            await loadProfile()
            await loadUserPosts()
            if isOwnProfile {
                await loadLikedPosts()
                await loadFollowingUsers()
            }
            if !isOwnProfile { await checkFollowing() }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
                .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(draftManager)
        }
        .sheet(isPresented: $showFollowingList) {
            FollowingListView(users: followingUsers)
                .environmentObject(authViewModel)
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(
                post: post,
                isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                onLike: { Task { await postsViewModel.toggleLike(post: post) } },
                onDeleted: { deletedPost in
                    userPosts.removeAll { $0.id == deletedPost.id }
                }
            )
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            let avatarId = profileUser?.avatar_id ?? "bear"
            let bgColor = Color(hex: profileUser?.avatar_bg_color ?? "#FFEEBA")
            Group {
                if avatarId.hasPrefix("https://") {
                    AsyncImage(url: URL(string: avatarId)) { img in
                        img.resizable().scaledToFill()
                    } placeholder: {
                        Color.ecruBackground
                    }
                } else if avatarImageNames.contains(avatarId) {
                    Image(avatarId)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(avatarId)
                        .font(.system(size: 56))
                }
            }
            .frame(width: 80, height: 80)
            .background(bgColor)
            .clipShape(Circle())

            // Display name
            if let name = profileUser?.display_name, !name.isEmpty {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
            }
            // Unique user ID
            if let uid = profileUser?.unique_user_id, !uid.isEmpty {
                Text("@\(uid)")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            // Stats
            HStack(spacing: 24) {
                statView(count: userPosts.count, label: "投稿")
                statView(count: profileUser?.followers_count ?? 0, label: "フォロワー")
                if isOwnProfile {
                    Button {
                        Task {
                            await loadFollowingUsers()
                            showFollowingList = true
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(followingCount)")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("フォロー")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Action button
            if !isOwnProfile {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Text(isFollowing ? "フォロー中" : "フォローする")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isFollowing ? Color(.systemGray5) : Color.accentBlue)
                        .cornerRadius(12)
                }
            }
        }
    }

    @ViewBuilder
    private func statView(count: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.accentRed : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            // グリッド/リスト切り替えボタン
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isGridMode.toggle()
                }
            } label: {
                Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 18))
                    .foregroundColor(.accentRed)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 12)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Posts List / Grid

    private var postsGrid: some View {
        Group {
            if isGridMode {
                profileMiniGrid(posts: userPosts)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userPosts, id: \.post_id) { post in
                        CompactPostCardView(
                            post: post,
                            isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                            onLike: {
                                Task { await postsViewModel.toggleLike(post: post) }
                            },
                            onTap: {
                                selectedPost = post
                            },
                            onReport: isOwnProfile ? nil : {
                                Task { await postsViewModel.report(post: post) }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Data

    private func loadProfile() async {
        isLoading = true
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            profileUser = try doc.data(as: AppUser.self)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadUserPosts() async {
        do {
            let snap = try await db.collection("posts")
                .whereField("user_id", isEqualTo: userId)
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .getDocuments()
            var posts = try snap.documents.map { try $0.data(as: Post.self) }
            // 投稿者情報（表示名・子供名）を付加
            if let userData = try? await db.collection("users").document(userId).getDocument(),
               let data = userData.data() {
                let displayName = (data["display_name"] as? String) ?? (data["unique_user_id"] as? String)
                let avatarId = data["avatar_id"] as? String ?? "bear"
                let avatarBgColor = data["avatar_bg_color"] as? String
                let children = data["children"] as? [[String: Any]]
                let childName = children?.first?["name"] as? String
                posts = posts.map { post in
                    var p = post
                    p.posterDisplayName = displayName
                    p.posterAvatarId = avatarId
                    p.posterAvatarBgColor = avatarBgColor
                    p.posterChildAgeName = childName
                    return p
                }
            }
            userPosts = posts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadLikedPosts() async {
        guard let myId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            // Get liked post IDs
            let likesSnap = try await db.collection("likes")
                .whereField("user_id", isEqualTo: myId)
                .getDocuments()
            let likedPostIds = likesSnap.documents.compactMap { $0.data()["post_id"] as? String }
            guard !likedPostIds.isEmpty else {
                likedPosts = []
                return
            }
            // Fetch posts in batches (Firestore 'in' query has limit of 10)
            var posts: [Post] = []
            for batch in likedPostIds.chunked(into: 10) {
                let snap = try await db.collection("posts")
                    .whereField("post_id", in: batch)
                    .whereField("is_hidden", isEqualTo: false)
                    .getDocuments()
                let batchPosts = try snap.documents.map { try $0.data(as: Post.self) }
                posts.append(contentsOf: batchPosts)
            }
            // Sort by created_at descending
            likedPosts = posts.sorted { $0.created_at.dateValue() > $1.created_at.dateValue() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Liked Posts List / Grid

    private var likedPostsGrid: some View {
        Group {
            if isGridMode {
                profileMiniGrid(posts: likedPosts)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(likedPosts, id: \.post_id) { post in
                        CompactPostCardView(
                            post: post,
                            isLiked: true,
                            onLike: {
                                Task { await postsViewModel.toggleLike(post: post) }
                            },
                            onTap: {
                                selectedPost = post
                            },
                            onReport: {
                                Task { await postsViewModel.report(post: post) }
                            }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func profileMiniGrid(posts: [Post]) -> some View {
        let cellSize = (UIScreen.main.bounds.width - 32 - 16) / 3
        let columns = [
            GridItem(.fixed(cellSize), spacing: 8),
            GridItem(.fixed(cellSize), spacing: 8),
            GridItem(.fixed(cellSize), spacing: 8)
        ]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(posts, id: \.post_id) { post in
                MiniPostCardView(
                    post: post,
                    isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                    onLike: {
                        Task { await postsViewModel.toggleLike(post: post) }
                    },
                    onTap: {
                        selectedPost = post
                    }
                )
                .frame(width: cellSize, height: cellSize * 1.3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func checkFollowing() async {
        guard let myId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let snap = try? await db.collection("follows")
            .whereField("follower_id", isEqualTo: myId)
            .whereField("following_id", isEqualTo: userId)
            .getDocuments()
        isFollowing = !(snap?.isEmpty ?? true)
    }

    private func toggleFollow() async {
        guard let myId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let followId = "\(myId)_\(userId)"
        let ref = db.collection("follows").document(followId)
        let userRef = db.collection("users").document(userId)

        if isFollowing {
            try? await ref.delete()
            try? await userRef.updateData(["followers_count": FieldValue.increment(Int64(-1))])
            profileUser?.followers_count = max(0, (profileUser?.followers_count ?? 0) - 1)
        } else {
            let follow = Follow(
                follow_id: followId,
                follower_id: myId,
                following_id: userId,
                created_at: Timestamp(date: Date())
            )
            try? ref.setData(from: follow)
            try? await userRef.updateData(["followers_count": FieldValue.increment(Int64(1))])
            profileUser?.followers_count = (profileUser?.followers_count ?? 0) + 1
        }
        isFollowing.toggle()
    }

    private func loadFollowingUsers() async {
        guard let myId = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("follows")
                .whereField("follower_id", isEqualTo: myId)
                .getDocuments()
            let followingIds = snap.documents.compactMap { $0.data()["following_id"] as? String }
            followingCount = followingIds.count
            guard !followingIds.isEmpty else {
                followingUsers = []
                return
            }
            var users: [AppUser] = []
            for uid in followingIds {
                if let doc = try? await db.collection("users").document(uid).getDocument(),
                   let user = try? doc.data(as: AppUser.self) {
                    users.append(user)
                }
            }
            followingUsers = users
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Following List View

struct FollowingListView: View {
    let users: [AppUser]
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserId: String? = nil
    @State private var selectedUserPosts: [Post] = []
    @State private var showUserPosts = false
    @State private var isLoadingPosts = false

    var body: some View {
        NavigationView {
            List {
                if users.isEmpty {
                    Text("フォロー中のアカウントがありません")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    ForEach(users, id: \.user_id) { user in
                        Button {
                            Task {
                                await loadUserPosts(userId: user.user_id)
                                selectedUserId = user.user_id
                                showUserPosts = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                // Avatar
                                let avatarId = user.avatar_id ?? "bear"
                                let bgColor = Color(hex: user.avatar_bg_color ?? "#FFEEBA")
                                Group {
                                    if avatarId.hasPrefix("https://") {
                                        AsyncImage(url: URL(string: avatarId)) { img in
                                            img.resizable().scaledToFill()
                                        } placeholder: {
                                            Color.ecruBackground
                                        }
                                    } else if avatarImageNames.contains(avatarId) {
                                        Image(avatarId).resizable().scaledToFill()
                                    } else {
                                        Text(avatarId)
                                            .font(.system(size: 24))
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .background(bgColor)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.display_name ?? "名前未設定")
                                        .font(.system(size: 15, weight: .semibold))
                                    if let uid = user.unique_user_id, !uid.isEmpty {
                                        Text("@\(uid)")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("フォロー中")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showUserPosts) {
                UserPostsSheet(userId: selectedUserId ?? "", posts: selectedUserPosts, isLoading: isLoadingPosts)
                    .environmentObject(authViewModel)
                    .environmentObject(postsViewModel)
            }
        }
    }

    private func loadUserPosts(userId: String) async {
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        do {
            let snap = try await Firestore.firestore().collection("posts")
                .whereField("user_id", isEqualTo: userId)
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .getDocuments()
            selectedUserPosts = try snap.documents.map { try $0.data(as: Post.self) }
        } catch {
            selectedUserPosts = []
        }
    }
}

// MARK: - User Posts Sheet

struct UserPostsSheet: View {
    let userId: String
    let posts: [Post]
    let isLoading: Bool
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPost: Post? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if posts.isEmpty {
                    Text("投稿がありません")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    // 縦長カードリスト表示
                    LazyVStack(spacing: 12) {
                        ForEach(posts, id: \.post_id) { post in
                            CompactPostCardView(
                                post: post,
                                isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                                onLike: {
                                    Task { await postsViewModel.toggleLike(post: post) }
                                },
                                onTap: {
                                    selectedPost = post
                                },
                                onReport: {
                                    Task { await postsViewModel.report(post: post) }
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(
                    post: post,
                    isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                    onLike: { Task { await postsViewModel.toggleLike(post: post) } },
                    onDeleted: { _ in }
                )
                    .environmentObject(authViewModel)
                    .environmentObject(postsViewModel)
            }
        }
    }
}
