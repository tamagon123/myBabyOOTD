import SwiftUI
import FirebaseFirestore

struct PostCardView: View {
    let post: Post
    let isLiked: Bool
    let onLike: () -> Void
    let onReport: () -> Void

    @State private var currentImageIndex: Int = 0
    @State private var showReportAlert = false
    @State private var navigateToProfile = false
    @State private var showItemTags = false
    @State private var postItems: [PostItem] = []
    @State private var itemsLoaded = false

    private var imageURLs: [String] {
        [post.image_url_front, post.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            NavigationLink(destination: ProfileView(userId: post.user_id), isActive: $navigateToProfile) {
                EmptyView()
            }
            HStack(spacing: 12) {
                Button {
                    navigateToProfile = true
                } label: {
                    HStack(spacing: 10) {
                        // Avatar
                        let avatarId = post.posterAvatarId ?? "🐶"
                        Group {
                            if avatarImageNames.contains(avatarId) {
                                Image(avatarId)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Text(avatarId)
                                    .font(.system(size: 20))
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(Color(.systemYellow).opacity(0.3))
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(post.posterDisplayName ?? "名前未設定")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                            Text(ageLabel(months: post.child_age_months) + " • " + regionLabel(code: post.region_code) + " • " + timeAgo(ts: post.created_at))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)

            // Photo carousel with item tag overlay
            photoCarousel

            // Tags: weather
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    weatherBadge
                    if !(post.item_tags ?? []).isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: showItemTags ? "tag.fill" : "tag")
                            Text("アイテム")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.indigo.opacity(0.08))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Description
            if !post.description.isEmpty {
                Text(post.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            // Footer
            HStack {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .foregroundColor(isLiked ? .pink : .gray)
                        Text("\(post.likes_count)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isLiked ? .pink : .gray)
                    }
                }
                Spacer()
                Button {
                    showReportAlert = true
                } label: {
                    Label("通報", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .alert("この投稿を通報しますか？", isPresented: $showReportAlert) {
            Button("通報する", role: .destructive, action: onReport)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("不適切なコンテンツとして報告されます。")
        }
    }

    // MARK: - Photo Carousel

    private var visibleItemTags: [PostItemTag] {
        guard showItemTags else { return [] }
        let side = currentImageIndex == 0 ? "front" : "back"
        return (post.item_tags ?? []).filter { $0.image_side == side }
    }

    private var photoCarousel: some View {
        ZStack(alignment: .topLeading) {
            if imageURLs.isEmpty {
                photoPlaceholder
            } else {
                TabView(selection: $currentImageIndex) {
                    ForEach(imageURLs.indices, id: \.self) { idx in
                        AsyncImage(url: URL(string: imageURLs[idx])) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .failure:
                                photoPlaceholder
                            default:
                                Color(.systemGray5).overlay(ProgressView())
                            }
                        }
                        .clipped()
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .always : .never))
                .frame(height: UIScreen.main.bounds.width - 32)
                .onTapGesture {
                    if !(post.item_tags ?? []).isEmpty {
                        if !itemsLoaded { loadItems() }
                        withAnimation(.easeInOut(duration: 0.2)) { showItemTags.toggle() }
                    }
                }

                GeometryReader { geo in
                    ForEach(visibleItemTags) { tag in
                        itemTagDot(
                            item: postItems.indices.contains(tag.item_index)
                                ? postItems[tag.item_index] : nil,
                            position: CGPoint(
                                x: CGFloat(tag.x_ratio) * geo.size.width,
                                y: CGFloat(tag.y_ratio) * geo.size.height
                            )
                        )
                    }
                }
                .allowsHitTesting(false)
                .frame(height: UIScreen.main.bounds.width - 32)
            }
        }
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Item Tag Dot

    @ViewBuilder
    private func itemTagDot(item: PostItem?, position: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // White dot
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 3)
                Circle()
                    .strokeBorder(Color.indigo.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }

            // Connector line (short)
            Rectangle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 1, height: 10)
                .shadow(color: .black.opacity(0.2), radius: 1)
                .opacity(item == nil ? 0 : 1)

            // Label with brand and size
            if let item = item {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.custom_name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(item.size_value)cm")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
        .position(x: position.x, y: position.y)
        .transition(.opacity)
    }

    private func loadItems() {
        guard let postId = post.id else { return }
        itemsLoaded = true
        let db = Firestore.firestore()
        Task {
            let snap = try? await db.collection("posts").document(postId).collection("items").getDocuments()
            let loaded = (snap?.documents ?? []).compactMap { try? $0.data(as: PostItem.self) }
            await MainActor.run { postItems = loaded }
        }
    }

    // MARK: - Sub views

    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemIndigo).opacity(0.08))
            .frame(height: UIScreen.main.bounds.width - 32)
            .overlay(
                Text("📷")
                    .font(.system(size: 40))
            )
            .padding(.horizontal, 16)
    }

    private var weatherBadge: some View {
        let wt = WeatherType(rawValue: post.weather_type)
        return Text("\(wt?.emoji ?? "🌤") \(Int(post.temp_max))℃ / \(Int(post.temp_min))℃")
            .tagStyle(bg: Color.blue.opacity(0.1), fg: Color.blue.opacity(0.8))
    }

    // MARK: - Helpers

    private func ageLabel(months: Int) -> String {
        if months < 12 { return "生後\(months)ヶ月" }
        let y = months / 12
        let m = months % 12
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)ヶ月"
    }

    private func regionLabel(code: String) -> String {
        guard let idx = Int(code), idx >= 1, idx <= prefectures.count else { return code }
        return prefectures[idx - 1]
    }

    private func timeAgo(ts: Timestamp) -> String {
        let seconds = Int(Date().timeIntervalSince(ts.dateValue()))
        switch seconds {
        case 0..<60:   return "たった今"
        case 0..<3600: return "\(seconds / 60)分前"
        case 0..<86400: return "\(seconds / 3600)時間前"
        default:        return "\(seconds / 86400)日前"
        }
    }
}

// MARK: - Tag style modifier

private extension Text {
    func tagStyle(bg: Color, fg: Color) -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg)
            .cornerRadius(16)
    }
}

