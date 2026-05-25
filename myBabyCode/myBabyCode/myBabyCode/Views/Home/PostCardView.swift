// =============================================================================
// ファイル名: PostCardView.swift
// 役割: タイムライン上の個別投稿カード表示（写真・投稿者情報・アイテムタグ・いいね・通報）
// 説明:
//   HomeViewのLazyVStack内で、投稿1件分を表示するカードViewです。
//   写真カルーセル（TabView）、投稿者情報（アバター・名前・年齢・地域・時間）、
//   アイテムタグ（写真上のドット表示）、天気バッジ、いいねボタン、通報ボタン、
//   説明文などを含みます。タップでPostDetailView（詳細画面）へ遷移します。
// =============================================================================

import SwiftUI
import FirebaseFirestore

struct PostCardView: View {
    // === 入力パラメータ ===
    let post: Post              // 表示する投稿データ
    let isLiked: Bool           // 自分がいいね済みか（ハートの塗りつぶし判定）
    let onLike: () -> Void      // いいねボタンタップ時のコールバック
    let onReport: () -> Void    // 通報ボタンタップ時のコールバック

    // === 内部状態 ===
    @State private var currentImageIndex: Int = 0     // 写真カルーセルの現在表示インデックス
    @State private var showReportAlert = false        // 通報確認アラートの表示状態
    @State private var navigateToProfile = false      // プロフィール画面へのナビゲーションフラグ
    @State private var showPostDetail = false         // 投稿詳細シートの表示状態
    @State private var showItemTags = false           // アイテムタグの表示/非表示
    @State private var postItems: [PostItem] = []     // Firestoreから取得した投稿アイテム
    @State private var itemsLoaded = false            // アイテムがロード済みか
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel

    // 計算プロパティ: frontとbackの画像URLを配列化（nil/空文字は除外）
    private var imageURLs: [String] {
        [post.image_url_front, post.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 投稿カードのレイアウトを定義
    // 構成:
    //   1. ヘッダー: 投稿者アバター＋表示名＋子供年齢・地域・時間
    //   2. Photo Carousel: TabViewでfront/back画像をスワイプ表示＋タグオーバーレイ
    //   3. タグエリア: 天気バッジ＋アイテムタグ表示ボタン
    //   4. 未タグ付けアイテム一覧（タグ位置未設定のアイテム）
    //   5. 説明文（3行制限）
    //   6. フッター: いいねボタン＋通報ボタン
    // =============================================================================
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
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(avatarBg)
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
                    if !(post.item_tags ?? []).isEmpty || (itemsLoaded && !postItems.isEmpty) {
                        Button {
                            if !itemsLoaded { loadItems() }
                            withAnimation(.easeInOut(duration: 0.2)) { showItemTags.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: showItemTags ? "tag.fill" : "tag")
                                Text("アイテム")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.accentGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentGreen.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            // Untagged items list (items with no photo tag assigned)
            if showItemTags && itemsLoaded && !untaggedItems.isEmpty {
                untaggedItemsView
                    .transition(.opacity)
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
        .sheet(isPresented: $showPostDetail) {
            PostDetailView(post: post, onDeleted: { _ in })
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
        }
        .onTapGesture {
            showPostDetail = true
        }
    }

    // MARK: - Photo Carousel
    // 説明: 投稿写真のカルーセル表示＋アイテムタグオーバーレイ

    // 計算プロパティ: 現在表示中の画像面（front/back）に対応するタグのみを抽出
    private var visibleItemTags: [PostItemTag] {
        guard showItemTags && itemsLoaded else { return [] }
        let side = currentImageIndex == 0 ? "front" : "back"
        return (post.item_tags ?? []).filter { $0.image_side == side }
    }

    // =============================================================================
    // 【Viewサマリー】photoCarousel
    // 目的: 投稿写真をTabViewでカルーセル表示し、アイテムタグをオーバーレイする
    // 戻り値: some View
    // 構成:
    //   - 画像URLがない場合: photoPlaceholder
    //   - ある場合: TabView（.pageスタイル）+ CachedAsyncImageで画像表示
    //   - タップでshowItemTags.toggle()
    //   - GeometryReader上にvisibleItemTagsをドット＋ラベルでオーバーレイ
    // =============================================================================
    private var photoCarousel: some View {
        ZStack(alignment: .topLeading) {
            if imageURLs.isEmpty {
                photoPlaceholder
            } else {
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
                .frame(height: UIScreen.main.bounds.width - 32)
                .onTapGesture {
                    if !itemsLoaded { loadItems() }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showItemTags.toggle()
                    }
                }
                .onAppear {
                    if !itemsLoaded {
                        loadItems()
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
    // 説明: 写真上に配置されるアイテムタグのドット＋ラベル表示

    // =============================================================================
    // 【Viewサマリー】itemTagDot
    // 目的: アイテムタグのドット（白丸＋赤枠）と、アイテム名・サイズのラベルを表示する
    // 引数:
    //   - item: PostItem? - タグに紐づくアイテム情報（nilの場合ラベルなし）
    //   - position: CGPoint - 写真上の配置座標（ピクセル座標）
    // 戻り値: some View
    // =============================================================================
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

    // =============================================================================
    // 【関数サマリー】loadItems
    // 目的: 投稿に紐づくアイテム情報をFirestoreのサブコレクションから取得する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. posts/{postId}/items サブコレクションを取得
    //   2. PostItem型にデコードしてpostItems配列にセット
    //   3. itemsLoaded = true
    // 呼び出し元: photoCarousel.onAppear, アイテムタグボタンタップ時
    // =============================================================================
    private func loadItems() {
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return }
        let db = Firestore.firestore()
        Task {
            do {
                let snap = try await db.collection("posts").document(postId).collection("items").getDocuments()
                let loaded = snap.documents.compactMap { try? $0.data(as: PostItem.self) }
                await MainActor.run { 
                    postItems = loaded
                    itemsLoaded = true
                }
            } catch {
                await MainActor.run { itemsLoaded = true }
            }
        }
    }

    // MARK: - Sub views
    // 説明: プレースホルダー・バッジ等のサブView定義

    // =============================================================================
    // 【Viewサマリー】photoPlaceholder
    // 目的: 画像がない場合のプレースホルダーを表示する
    // 戻り値: some View
    // =============================================================================
    private var photoPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.ecruBackground)
            .frame(height: UIScreen.main.bounds.width - 32)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.4))
            )
            .padding(.horizontal, 16)
    }

    // =============================================================================
    // 【Viewサマリー】weatherBadge
    // 目的: 天気アイコン＋最高/最低気温のバッジを表示する
    // 戻り値: some View
    // =============================================================================
    private var weatherBadge: some View {
        let wt = WeatherType(rawValue: post.weather_type)
        return Label("\(Int(post.temp_max))℃ / \(Int(post.temp_min))℃", systemImage: wt?.sfSymbol ?? "cloud.sun")
            .tagStyle(bg: Color.blue.opacity(0.1), fg: Color.blue.opacity(0.8))
    }

    // MARK: - Helpers
    // 説明: 表示用ラベル文字列の生成ヘルパー

    // =============================================================================
    // 【関数サマリー】ageLabel
    // 目的: 月数を「生後Xヶ月」または「Y歳Zヶ月」という日本語表記に変換する
    // 引数:
    //   - months: Int - 月数
    // 戻り値: String - 人間が読める年齢表記
    // =============================================================================
    private func ageLabel(months: Int) -> String {
        if months < 12 { return "生後\(months)ヶ月" }
        let y = months / 12
        let m = months % 12
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)ヶ月"
    }

    // =============================================================================
    // 【関数サマリー】regionLabel
    // 目的: 都道府県コードを都道府県名に変換する
    // 引数:
    //   - code: String - 2桁の都道府県コード（"01"〜"47"）
    // 戻り値: String - 都道府県名（例: "東京都"）
    // =============================================================================
    private func regionLabel(code: String) -> String {
        guard let idx = Int(code), idx >= 1, idx <= prefectures.count else { return code }
        return prefectures[idx - 1]
    }

    // =============================================================================
    // 【関数サマリー】timeAgo
    // 目的: Firestore Timestampから「たった今」「X分前」「Y時間前」「Z日前」に変換する
    // 引数:
    //   - ts: Timestamp - Firestoreのタイムスタンプ
    // 戻り値: String - 相対時間表記
    // =============================================================================
    private func timeAgo(ts: Timestamp) -> String {
        let seconds = Int(Date().timeIntervalSince(ts.dateValue()))
        switch seconds {
        case 0..<60:   return "たった今"
        case 0..<3600: return "\(seconds / 60)分前"
        case 0..<86400: return "\(seconds / 3600)時間前"
        default:        return "\(seconds / 86400)日前"
        }
    }

    // MARK: - Untagged items view
    // 説明: 写真上にタグ付けされていないアイテムの一覧表示

    // 計算プロパティ: タグ位置が設定されていないアイテム（未タグ付け）を抽出
    private var untaggedItems: [PostItem] {
        guard itemsLoaded else { return [] }
        let taggedIndices = Set((post.item_tags ?? []).map { $0.item_index })
        return postItems.indices.compactMap { idx in
            taggedIndices.contains(idx) ? nil : postItems[idx]
        }
    }

    // =============================================================================
    // 【Viewサマリー】untaggedItemsView
    // 目的: タグ付けされていないアイテムをリスト形式で表示する
    // 戻り値: some View
    // =============================================================================
    private var untaggedItemsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(untaggedItems) { item in
                HStack(spacing: 8) {
                    Text(item.custom_name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(sizeLabel(item.size_value))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
    }
}

// MARK: - Tag style modifier

private extension View {
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

