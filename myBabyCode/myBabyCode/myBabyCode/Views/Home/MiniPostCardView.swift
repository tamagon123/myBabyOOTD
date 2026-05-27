// =============================================================================
// ファイル名: MiniPostCardView.swift
// 役割: グリッド表示用の縮小投稿カード（3列グリッド用）
// 説明:
//   HomeViewのグリッド表示で使用する縮小版の投稿カードです。
//   写真、投稿者アバター、いいねボタンを表示し、タップで詳細画面へ遷移します。
//   一覧からいいねボタンを押下可能です。
// =============================================================================

import SwiftUI

struct MiniPostCardView: View {
    let post: Post
    let isLiked: Bool
    let onLike: () -> Void
    let onTap: () -> Void
    var showInfo: Bool = true  // アバター・名前を表示するか
    
    @State private var showingLikeAnimation = false
    
    var body: some View {
        GeometryReader { geo in
        ZStack(alignment: .bottomLeading) {
            // メイン画像（親サイズに確実に収める）
            Button(action: onTap) {
                let url = post.image_url_front ?? post.image_url_back
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
                                .foregroundColor(.secondary)
                        )
                }
            }
            .buttonStyle(.plain)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            
            // グラデーションオーバーレイ（下部情報表示用）
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)
            .frame(maxHeight: .infinity, alignment: .bottom)
            
            // 下部情報バー
            HStack(spacing: 8) {
                if showInfo {
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
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 24, height: 24)
                .background(avatarBg)
                .clipShape(Circle())
                
                // 表示名（短縮）
                Text(post.posterDisplayName ?? "名前未設定")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                } // showInfo
                
                Spacer()
                
                // いいねボタン
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        showingLikeAnimation = true
                    }
                    onLike()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingLikeAnimation = false
                    }
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isLiked ? .accentRed : .white)
                        .scaleEffect(showingLikeAnimation ? 1.3 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: geo.size.width, height: geo.size.height)
        .clipped()
        .cornerRadius(8)
        } // GeometryReader
    }
}
