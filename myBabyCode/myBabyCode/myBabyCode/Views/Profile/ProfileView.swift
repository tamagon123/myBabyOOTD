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
    @State private var showNotifications = false       // 通知一覧画面表示フラグ
    @State private var selectedPost: Post? = nil     // タップされた投稿（詳細画面へ）
    @State private var selectedTab: ProfileTab = .posts  // 選択中のタブ（投稿/いいね）
    @State private var showFollowingList = false       // フォロー一覧表示フラグ
    @State private var followingUsers: [AppUser] = [] // フォロー中のユーザーリスト
    @State private var followingCount: Int = 0         // フォロー中の件数
    @State private var isGridMode: Bool = true         // グリッド/リスト表示モード（デフォルトはグリッド）
    @State private var calendarIsPublic: Bool = false   // カレンダー公開設定
    @State private var showPublicCalendar: Bool = false  // 公開カレンダー表示フラグ
    @State private var publicCalendarUserId: String? = nil // 公開カレンダーの対象UID

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
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // タブセレクター（自分のプロフィール時のみ）・他アカウントは切り替えボタンのみ
                if isOwnProfile {
                    tabSelector
                } else {
                    // 他アカウント用：グリッド/リスト切り替えボタンのみ
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { isGridMode.toggle() }
                        } label: {
                            Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                                .font(.system(size: 18))
                                .foregroundColor(.accentRed)
                                .frame(width: 36, height: 36)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 8)
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
        .navigationViewStyle(StackNavigationViewStyle())
        .background(Color.ecruBackground.ignoresSafeArea())
        // 設定ボタンはヘッダーカード内に統合済み
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
            NavigationView {
                EditProfileView()
                    .environmentObject(authViewModel)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(authViewModel)
                .environmentObject(draftManager)
        }
        .sheet(isPresented: $showNotifications) {
            NavigationView {
                NotificationsView()
                    .environmentObject(authViewModel)
            }
            .navigationViewStyle(StackNavigationViewStyle())
        }
        .sheet(isPresented: $showFollowingList) {
            FollowingListView()
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
        }
        .sheet(isPresented: $showPublicCalendar) {
            if let targetUid = publicCalendarUserId {
                PublicCalendarView(userId: targetUid)
            }
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(
                post: post,
                isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                onLike: { Task { await postsViewModel.toggleLike(post: post) } },
                onDeleted: { deletedPost in
                    // post_idを使用して一致する投稿を削除（idは@DocumentIDなので使用しない）
                    userPosts.removeAll { $0.post_id == deletedPost.post_id }
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
        VStack(spacing: 0) {
            // ── 上部: アバター・名前・ID・設定ボタン ──
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 12) {
                        // Avatar (大きく、枠線・影付き)
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
                                    .font(.system(size: 72))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .background(bgColor)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                        )
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

                        // Display name
                        if let name = profileUser?.display_name, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        // Unique user ID
                        if let uid = profileUser?.unique_user_id, !uid.isEmpty {
                            Text("@\(uid)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // 設定・通知ボタン（自分のプロフィール時のみ、右上）
                    if isOwnProfile {
                        HStack(spacing: 12) {
                            Button {
                                showNotifications = true
                            } label: {
                                Image(systemName: "bell")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }

                // 子供情報チップ
                if let children = profileUser?.children, !children.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(children.indices, id: \.self) { idx in
                                let child = children[idx]
                                let name = child.name
                                let ageText = childAgeText(child)
                                HStack(spacing: 4) {
                                    Image(systemName: "figure.child")
                                        .font(.system(size: 12))
                                    Text("\(name) \(ageText)")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentRed.opacity(0.10))
                                .foregroundColor(.accentRed)
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                // プロフィール編集ボタン（自分のプロフィール時のみ）
                if isOwnProfile {
                    Button {
                        showEditProfile = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                                .font(.system(size: 13, weight: .medium))
                            Text("プロフィールを編集")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }

                // フォローボタン（他ユーザーの場合）
                if !isOwnProfile {
                    Button {
                        Task { await toggleFollow() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isFollowing ? "checkmark" : "person.badge.plus")
                                .font(.system(size: 13, weight: .medium))
                            Text(isFollowing ? "フォロー中" : "フォローする")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isFollowing ? Color(.systemGray5) : Color.accentBlue)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)

            Divider()
                .padding(.top, 16)
                .padding(.horizontal, 20)

            // ── 統計カード横並び ──
            HStack(spacing: 0) {
                statCard(count: userPosts.count, label: "投稿", icon: "photo.on.rectangle")
                Divider().frame(height: 40)
                statCard(count: profileUser?.followers_count ?? 0, label: "フォロワー", icon: "person.2")
                if isOwnProfile {
                    Divider().frame(height: 40)
                    Button {
                        showFollowingList = true
                    } label: {
                        statCardContent(count: followingCount, label: "フォロー", icon: "person.2.fill")
                    }
                    .buttonStyle(.plain)
                } else {
                    Divider().frame(height: 40)
                    statCardContent(count: followingCount, label: "フォロー", icon: "person.2.fill")
                }
            }
            .padding(.vertical, 12)

            // ── カレンダー設定 / 公開カレンダー閲覧 ──
            calendarSettingsRow
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    /// 統計カード（タップ不可）
    @ViewBuilder
    private func statCard(count: Int, label: String, icon: String) -> some View {
        statCardContent(count: count, label: label, icon: icon)
            .frame(maxWidth: .infinity)
    }

    /// 統計カードの中身
    @ViewBuilder
    private func statCardContent(count: Int, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentRed)
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// カレンダー設定 / 公開カレンダー閲覧行
    @ViewBuilder
    private var calendarSettingsRow: some View {
        Button {
            if isOwnProfile {
                showSettings = true
            } else {
                publicCalendarUserId = userId
                showPublicCalendar = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(.accentRed)
                    .frame(width: 32, height: 32)
                    .background(Color.accentRed.opacity(0.1))
                    .cornerRadius(8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isOwnProfile ? "カレンダー設定" : "カレンダーを見る")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                    if isOwnProfile {
                        Text(calendarIsPublic ? "公開中：他のユーザーにカレンダーが表示されます" : "非公開：カレンダーは自分だけが見られます")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.systemGray))
                    } else if calendarIsPublic {
                        Text("このユーザーのカレンダーを閲覧できます")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.systemGray))
                    } else {
                        Text("カレンダーは非公開に設定されています")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.systemGray3))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(.systemGray3))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .disabled(!isOwnProfile && !calendarIsPublic)
        .buttonStyle(.plain)
        .opacity(!isOwnProfile && !calendarIsPublic ? 0.5 : 1.0)
    }

    /// 空の状態表示（Empty State）
    @ViewBuilder
    private func emptyStateView(icon: String, title: String, message: String?) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color(.systemGray4))
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
            if let message = message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(Color(.systemGray3))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    /// 子供の年齢テキストを生成
    private func childAgeText(_ child: ChildProfile) -> String {
        let birth = child.birthday
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: birth, to: now)
        if let year = components.year, year > 0 {
            if let month = components.month, month > 0 {
                return "(\(year)歳\(month)ヶ月)"
            }
            return "(\(year)歳)"
        } else if let month = components.month, month > 0 {
            return "(\(month)ヶ月)"
        }
        return ""
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            // ピル型セグメントタブ
            HStack(spacing: 4) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab == .posts ? "photo.on.rectangle" : "heart.fill")
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                        }
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentRed : Color.clear)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color(.systemGray6))
            .clipShape(Capsule())

            Spacer()

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
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Posts List / Grid

    private var postsGrid: some View {
        Group {
            if userPosts.isEmpty {
                emptyStateView(
                    icon: "photo.on.rectangle.angled",
                    title: isOwnProfile ? "まだ投稿がありません" : "投稿がありません",
                    message: isOwnProfile ? "子供のコーデを投稿してシェアしよう" : nil
                )
            } else if isGridMode {
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
            calendarIsPublic = doc.data()?["calendar_is_public"] as? Bool ?? false
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
            if likedPosts.isEmpty {
                emptyStateView(
                    icon: "heart.slash",
                    title: "いいねした投稿がありません",
                    message: "気に入ったコーデにいいねしてみよう"
                )
            } else if isGridMode {
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
                    },
                    showInfo: false
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
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var users: [AppUser] = []
    @State private var isLoading = true
    @State private var selectedUserId: String? = nil
    @State private var selectedUserPosts: [Post] = []
    @State private var showUserPosts = false
    @State private var isLoadingPosts = false

    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else if users.isEmpty {
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
                                let avatarId = user.avatar_id
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
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await loadFollowingUsers()
        }
    }

    private func loadFollowingUsers() async {
        guard let myId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        do {
            let snap = try await Firestore.firestore().collection("follows")
                .whereField("follower_id", isEqualTo: myId)
                .getDocuments()
            let followingIds = snap.documents.compactMap { $0.data()["following_id"] as? String }
            guard !followingIds.isEmpty else {
                users = []
                isLoading = false
                return
            }
            var loadedUsers: [AppUser] = []
            for uid in followingIds {
                if let doc = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
                   let user = try? doc.data(as: AppUser.self) {
                    loadedUsers.append(user)
                }
            }
            users = loadedUsers
        } catch {
            users = []
        }
        isLoading = false
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
    @State private var isGridMode: Bool = true

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
                } else if isGridMode {
                    let cellSize = (UIScreen.main.bounds.width - 32 - 16) / 3
                    let columns = [
                        GridItem(.fixed(cellSize), spacing: 8),
                        GridItem(.fixed(cellSize), spacing: 8),
                        GridItem(.fixed(cellSize), spacing: 8)
                    ]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(posts, id: \.post_id) { post in
                            MiniPostCardView(
                                post: post,
                                isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                                onLike: { Task { await postsViewModel.toggleLike(post: post) } },
                                onTap: { selectedPost = post },
                                showInfo: false
                            )
                            .frame(width: cellSize, height: cellSize * 1.3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                } else {
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isGridMode.toggle() }
                    } label: {
                        Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                            .foregroundColor(.accentRed)
                    }
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
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
