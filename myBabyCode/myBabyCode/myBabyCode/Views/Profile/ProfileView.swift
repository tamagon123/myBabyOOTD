import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ProfileView: View {
    let userId: String
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var profileUser: AppUser?
    @State private var userPosts: [Post] = []
    @State private var isLoading = false
    @State private var isFollowing = false
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false

    private let db = Firestore.firestore()
    private var isOwnProfile: Bool { userId == FirebaseAuth.Auth.auth().currentUser?.uid }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Profile header
                profileHeader
                    .padding(.top, 16)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                // Posts grid
                if isLoading {
                    ProgressView().padding()
                } else {
                    postsGrid
                }
            }
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
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            let avatarId = profileUser?.avatar_id ?? "🐶"
            Group {
                if avatarImageNames.contains(avatarId) {
                    Image(avatarId)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(avatarId)
                        .font(.system(size: 56))
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemYellow).opacity(0.3))
            .clipShape(Circle())

            // Display name
            if let name = profileUser?.display_name, !name.isEmpty {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
            }

            // Stats
            HStack(spacing: 32) {
                statView(count: userPosts.count, label: "投稿")
                statView(count: profileUser?.followers_count ?? 0, label: "フォロワー")
            }

            // Child info
            if let user = profileUser {
                let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
                let ageStr = ageMonths < 12 ? "生後\(ageMonths)ヶ月" : "\(ageMonths/12)歳\(ageMonths%12 == 0 ? "" : "\(ageMonths%12)ヶ月")"
                let genderStr = ChildGender(rawValue: user.child_gender)?.label ?? "未選択"
                let region = (Int(user.region_code).map { $0 >= 1 && $0 <= 47 ? prefectures[$0 - 1] : user.region_code }) ?? user.region_code

                Text("\(ageStr) \(genderStr) • \(region)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Action button
            if isOwnProfile {
                Button {
                    showEditProfile = true
                } label: {
                    Text("プロフィールを編集")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }

                Button {
                    showSignOutAlert = true
                } label: {
                    Text("ログアウト")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .alert("ログアウト", isPresented: $showSignOutAlert) {
                    Button("キャンセル", role: .cancel) {}
                    Button("ログアウト", role: .destructive) {
                        authViewModel.signOut()
                    }
                } message: {
                    Text("ログアウトしますか？")
                }
            } else {
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Text(isFollowing ? "フォロー中" : "フォローする")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isFollowing ? .secondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isFollowing ? Color(.systemGray5) : Color.indigo)
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
            ForEach(userPosts) { post in
                let url = post.image_url_front ?? post.image_url_back
                AsyncImage(url: URL(string: url ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: cellSize, height: cellSize)
                            .clipped()
                    default:
                        Color(.systemIndigo).opacity(0.1)
                            .frame(width: cellSize, height: cellSize)
                            .overlay(Text("📷").font(.title))
                    }
                }
                .frame(width: cellSize, height: cellSize)
                .clipped()
            }
        }
    }

    // MARK: - Data

    private func loadProfile() async {
        isLoading = true
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            profileUser = try doc.data(as: AppUser.self)
        } catch {}
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
        } catch {}
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
