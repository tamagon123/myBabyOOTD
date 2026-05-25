// =============================================================================
// ファイル名: PostDetailView.swift
// 役割: 投稿の詳細表示画面（写真拡大・投稿者情報・アイテム詳細・投稿削除）
// 説明:
//   タイムラインの投稿カードをタップした際に表示される詳細画面です。
//   写真のTabViewカルーセル、投稿者情報、天気・気温情報、洋服アイテムの
//   詳細リスト（ブランド・カテゴリ・サイズ）、説明文を表示します。
//   自分の投稿の場合はゴミ箱アイコンから削除が可能です。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PostDetailView: View {
    // === 入力パラメータ ===
    let post: Post                              // 表示対象の投稿データ
    var onDeleted: ((Post) -> Void)? = nil      // 削除完了後のコールバック（オプション）

    // === 環境オブジェクト ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss  // シート/画面を閉じるための環境値

    // === 内部状態 ===
    @State private var currentImageIndex: Int = 0   // 写真カルーセルの現在表示インデックス
    @State private var showDeleteConfirm = false    // 削除確認アラートの表示状態
    @State private var isDeleting = false           // 削除処理中フラグ
    @State private var postItems: [PostItem] = []   // Firestoreから取得した投稿アイテム
    @State private var itemsLoaded = false          // アイテムロード済みフラグ
    @State private var showItemTags = false         // アイテムタグの表示/非表示

    // 計算プロパティ: 現在表示中の画像面に対応するタグのみ抽出
    private var visibleItemTags: [PostItemTag] {
        guard showItemTags && itemsLoaded else { return [] }
        let side = currentImageIndex == 0 ? "front" : "back"
        return (post.item_tags ?? []).filter { $0.image_side == side }
    }

    // 計算プロパティ: frontとbackの画像URLを配列化
    private var imageURLs: [String] {
        [post.image_url_front, post.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 投稿詳細画面の全体レイアウトを定義
    // 構成:
    //   1. ナビゲーションバー（閉じるボタン＋削除ボタン（自分の投稿時））
    //   2. ScrollView内に:
    //      - 写真カルーセル（TabView + アイテムタグオーバーレイ）
    //      - 投稿者情報（アバター・名前・年齢）
    //      - 天気・気温・地域バッジ
    //      - アイテム詳細リスト（各アイテムのブランド・カテゴリ・サイズ）
    //      - 説明文
    // =============================================================================
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Photo carousel
                    if imageURLs.isEmpty {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(Color.ecruBackground)
                            .frame(height: UIScreen.main.bounds.width)
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary.opacity(0.4))
                            )
                    } else {
                        ZStack(alignment: .topLeading) {
                            TabView(selection: $currentImageIndex) {
                                ForEach(imageURLs.indices, id: \.self) { idx in
                                    CachedAsyncImage(url: imageURLs[idx]) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            Color(.systemGray5).overlay(ProgressView())
                                        }
                                    .clipped()
                                    .tag(idx)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .always : .never))
                            .frame(height: UIScreen.main.bounds.width)
                            .onTapGesture {
                                if !itemsLoaded { Task { await loadItems() } }
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showItemTags.toggle()
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
                            .frame(height: UIScreen.main.bounds.width)
                        }
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        // Poster info
                        HStack(spacing: 12) {
                            let avatarId = post.posterAvatarId ?? "bear"
                            let avatarBg = Color(hex: post.posterAvatarBgColor ?? "#FFEEBA")
                            Group {
                                if avatarId.hasPrefix("https://") {
                                    AsyncImage(url: URL(string: avatarId)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: { Color.ecruBackground }
                                } else if avatarImageNames.contains(avatarId) {
                                    Image(avatarId).resizable().scaledToFill()
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(avatarBg)
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
                            Label(wt?.label ?? "", systemImage: wt?.sfSymbol ?? "cloud.sun")
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

                        // Items
                        if itemsLoaded && !postItems.isEmpty {
                            itemsSection
                        }
                    }
                    .padding(20)
                }
            }
            .task { await loadItems() }
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

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アイテム")
                .font(.system(size: 15, weight: .bold))

            ForEach(postItems.indices, id: \.self) { idx in
                let item = postItems[idx]
                let tags = (post.item_tags ?? []).filter { $0.item_index == idx }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.custom_name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                            Text(item.category)
                                .font(.system(size: 11))
                                .foregroundColor(.accentGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentGreen.opacity(0.1))
                                .cornerRadius(6)
                        }
                        Spacer()
                        Text(sizeLabel(item.size_value))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    if !tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(tags) { tag in
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.pink)
                                    Text(tag.image_side == "front" ? "フロント" : "バック")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.pink.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func loadItems() async {
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else {
            itemsLoaded = true
            return
        }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("posts").document(postId).collection("items").getDocuments()
            postItems = snap.documents.compactMap { try? $0.data(as: PostItem.self) }
        } catch {}
        itemsLoaded = true
    }

    private func ageLabel(months: Int) -> String {
        if months < 12 { return "生後\(months)ヶ月" }
        let y = months / 12
        let m = months % 12
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)ヶ月"
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
                    .strokeBorder(Color.accentRed.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }

            // Label with brand and size
            if let item = item {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.custom_name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(sizeLabel(item.size_value))
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
}

