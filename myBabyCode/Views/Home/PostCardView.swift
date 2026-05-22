import SwiftUI

struct PostCardView: View {
    let post: Post
    let isLiked: Bool
    let onLike: () -> Void
    let onReport: () -> Void

    @State private var currentImageIndex: Int = 0
    @State private var showReportAlert = false

    private var imageURLs: [String] {
        [post.image_url_front, post.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            HStack(spacing: 12) {
                Text(ChildGender(rawValue: post.gender_id)?.emoji ?? "🧒")
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Color(.systemYellow).opacity(0.4))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(ageLabel(months: post.child_age_months) + " " + (ChildGender(rawValue: post.gender_id)?.label ?? ""))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                    Text(regionLabel(code: post.region_code) + " • " + timeAgo(ts: post.created_at))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Photo carousel
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
                .cornerRadius(16)
                .padding(.horizontal, 16)
            }

            // Tags: weather + brand/size
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    weatherBadge
                    // Items not fetched in list for performance; show age/size tag
                    Text("サイズ不明")
                        .tagStyle(bg: Color(.systemYellow).opacity(0.25), fg: Color(.systemBrown))
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
