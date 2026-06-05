// =============================================================================
// ファイル名: CompactPostCardView.swift
// 役割: 縦長リスト表示用のコンパクト投稿カード
// 説明:
//   プロフィール画面等のリスト表示で使用する縦長カードです。
//   写真、投稿者情報、いいね・コメント数、説明文を表示します。
//   タップで詳細画面へ遷移し、いいねボタンを一覧から押下可能です。
// =============================================================================

import SwiftUI
import FirebaseFirestore

struct CompactPostCardView: View {
    let post: Post
    let isLiked: Bool
    let onLike: () -> Void
    let onTap: () -> Void
    let onReport: (() -> Void)?
    
    @State private var showingLikeAnimation = false
    
    private var postDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: post.created_at.dateValue())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ヘッダー: 投稿者情報
            HStack(spacing: 10) {
                // アバター
                let avatarId = post.posterAvatarId ?? "bear"
                let avatarBg = Color(hex: post.posterAvatarBgColor ?? "#FFEEBA")
                Group {
                    if avatarId.hasPrefix("https://") {
                        AsyncImage(url: URL(string: avatarId)) { img in
                            img.resizable().scaledToFill()
                        } placeholder: { Color.ecruBackground }
                    } else if avatarImageNames.contains(avatarId) {
                        Image(avatarId)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.appFont(.regular, size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 36, height: 36)
                .background(avatarBg)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.posterDisplayName ?? "名前未設定")
                        .font(.appFont(.medium, size: 13))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        if let childName = post.posterChildAgeName, !childName.isEmpty {
                            Text(childName)
                                .font(.appFont(.regular, size: 11))
                                .foregroundColor(.secondary)
                        }
                        Text(postDate)
                            .font(.appFont(.regular, size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 天気アイコン
                if let weatherType = WeatherType(rawValue: post.weather_type) {
                    Image(systemName: weatherType.sfSymbol)
                        .font(.appFont(.regular, size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // 写真（タップで詳細・横スクロール対応）
            let imageUrls = [post.image_url_front, post.image_url_back].compactMap { $0 }
            if imageUrls.count > 1 {
                TabView {
                    ForEach(imageUrls.indices, id: \.self) { idx in
                        Button(action: onTap) {
                            GeometryReader { geo in
                                CachedAsyncImage(url: imageUrls[idx]) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .clipped()
                                } placeholder: {
                                    Color(.systemGray5)
                                        .frame(width: geo.size.width, height: geo.size.height)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.appFont(.regular, size: 40))
                                                .foregroundColor(.secondary.opacity(0.4))
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 320)
            } else if let url = imageUrls.first {
                Button(action: onTap) {
                    GeometryReader { geo in
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } placeholder: {
                            Color(.systemGray5)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.appFont(.regular, size: 40))
                                        .foregroundColor(.secondary.opacity(0.4))
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(height: 320)
                .clipped()
            }
            
            // アクションバー
            HStack(spacing: 16) {
                // いいね
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        showingLikeAnimation = true
                    }
                    onLike()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingLikeAnimation = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.appFont(.medium, size: 18))
                            .foregroundColor(isLiked ? .accentRed : .primary)
                            .scaleEffect(showingLikeAnimation ? 1.3 : 1.0)
                        if post.likes_count > 0 {
                            Text("\(post.likes_count)")
                                .font(.appFont(.regular, size: 13))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // 通報（オプション）
                if let onReport = onReport {
                    Button(action: onReport) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.appFont(.regular, size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            
            // 説明文（3行制限）
            if !post.description.isEmpty {
                Text(post.description)
                    .font(.appFont(.regular, size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}
