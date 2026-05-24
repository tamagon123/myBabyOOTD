import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PostDetailView: View {
    let post: Post
    var onDeleted: ((Post) -> Void)? = nil
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentImageIndex: Int = 0
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false

    private var imageURLs: [String] {
        [post.image_url_front, post.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Photo carousel
                    if imageURLs.isEmpty {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color(.systemIndigo).opacity(0.08))
                            .frame(height: UIScreen.main.bounds.width)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.4))
                            )
                    } else {
                        TabView(selection: $currentImageIndex) {
                            ForEach(imageURLs.indices, id: \.self) { idx in
                                AsyncImage(url: URL(string: imageURLs[idx])) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFit()
                                    case .failure:
                                        Color(.systemGray5)
                                    default:
                                        Color(.systemGray5).overlay(ProgressView())
                                    }
                                }
                                .tag(idx)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .always : .never))
                        .frame(height: UIScreen.main.bounds.width)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        // Poster info
                        HStack(spacing: 12) {
                            let avatarId = post.posterAvatarId ?? "🐶"
                            Group {
                                if avatarImageNames.contains(avatarId) {
                                    Image(avatarId).resizable().scaledToFill()
                                } else {
                                    Text(avatarId).font(.system(size: 20))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(Color(.systemYellow).opacity(0.3))
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(post.posterDisplayName ?? "名前未設定")
                                    .font(.system(size: 15, weight: .bold))
                                Text(ageLabel(months: post.child_age_months))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }

                        // Weather / Temp
                        let wt = WeatherType(rawValue: post.weather_type)
                        HStack(spacing: 8) {
                            Text("\(wt?.emoji ?? "🌤") \(wt?.label ?? "")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.blue)
                            Spacer()
                            Text("最高 \(Int(post.temp_max))℃  最低 \(Int(post.temp_min))℃")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.07))
                        .cornerRadius(12)

                        // Region
                        let region: String = {
                            guard let idx = Int(post.region_code), idx >= 1, idx <= prefectures.count else { return post.region_code }
                            return prefectures[idx - 1]
                        }()
                        Label(region, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        // Description
                        if !post.description.isEmpty {
                            Text(post.description)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("投稿詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let uid = FirebaseAuth.Auth.auth().currentUser?.uid, uid == post.user_id {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(isDeleting)
                    }
                }
            }
            .alert("投稿を削除", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    Task {
                        isDeleting = true
                        let success = await postsViewModel.deletePost(post)
                        isDeleting = false
                        if success {
                            onDeleted?(post)
                            dismiss()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この投稿を削除しますか？この操作は取り消せません。")
            }
        }
    }

    private func ageLabel(months: Int) -> String {
        if months < 12 { return "生後\(months)ヶ月" }
        let y = months / 12
        let m = months % 12
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)ヶ月"
    }
}

