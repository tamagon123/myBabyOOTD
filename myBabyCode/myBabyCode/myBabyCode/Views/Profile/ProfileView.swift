import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    let userId: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var draftManager: DraftManager

    @State private var profileUser: AppUser?
    @State private var userPosts: [Post] = []
    @State private var isLoading = false
    @State private var isFollowing = false
    @State private var errorMessage: String? = nil
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var selectedPost: Post? = nil

    private let db = Firestore.firestore()
    private var isOwnProfile: Bool { userId == FirebaseAuth.Auth.auth().currentUser?.uid }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Profile header
                profileHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Posts grid
                if isLoading {
                    ProgressView().padding()
                } else {
                    postsGrid
                }
            }
        }
        .background(Color.ecruBackground.ignoresSafeArea())
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
        .refreshable {
            await loadProfile()
            await loadUserPosts()
            if !isOwnProfile { await checkFollowing() }
        }
        .task {
            await loadProfile()
            await loadUserPosts()
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
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post, onDeleted: { deletedPost in
                userPosts.removeAll { $0.id == deletedPost.id }
            })
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
            HStack(spacing: 32) {
                statView(count: userPosts.count, label: "投稿")
                statView(count: profileUser?.followers_count ?? 0, label: "フォロワー")
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

    // MARK: - Posts Grid

    private var postsGrid: some View {
        let cellSize = (UIScreen.main.bounds.width - 4) / 3
        let columns = [
            GridItem(.fixed(cellSize), spacing: 2),
            GridItem(.fixed(cellSize), spacing: 2),
            GridItem(.fixed(cellSize), spacing: 2)
        ]
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(userPosts, id: \.post_id) { post in
                let url = post.image_url_front ?? post.image_url_back
                Button {
                    selectedPost = post
                } label: {
                    CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } placeholder: {
                            Color.ecruBackground
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.title)
                                        .foregroundColor(.secondary.opacity(0.4))
                                )
                        }
                    .frame(width: cellSize, height: cellSize)
                    .clipped()
                }
                .buttonStyle(.plain)
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
            userPosts = try snap.documents.map { try $0.data(as: Post.self) }
        } catch {
            errorMessage = error.localizedDescription
        }
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
}

