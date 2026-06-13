// =============================================================================
// ファイル名: PostCardView.swift
// 役割: タイムライン上の個別投稿カード表示（写真・投稿者情報・アイテムタグ・いいね・通報）
// 説明:
//   HomeViewのLazyVStack内で、投稿1件分を表示するカードViewです。
//   写真カルーセル（TabView）、投稿者情報（アバター・名前・年齢・地域・時間）、
//   アイテムタグ（写真上のドット表示）、天気バッジ、いいねボタン、通報ボタン、
//   説明文などを含みます。タップでPostDetailView（詳細画面）へ遷移します。
//   iPad対応: disableDetailSheetフラグで詳細遷移を制御し、fullScreenCoverで表示。
// =============================================================================

import SwiftUI
import FirebaseFirestore

struct PostCardView: View {
    // === 入力パラメータ ===
    let post: Post              // 表示する投稿データ
    let isLiked: Bool           // 自分がいいね済みか（ハートの塗りつぶし判定）
    let onLike: () -> Void      // いいねボタンタップ時のコールバック
    let onReport: () -> Void    // 通報ボタンタップ時のコールバック
    var disableDetailSheet: Bool = false  // iPadリスト表示時に詳細シートを無効化

    // === 内部状態 ===
    @State private var currentImageIndex: Int = 0     // 写真カルーセルの現在表示インデックス
    @State private var showReportAlert = false        // 通報確認アラートの表示状態（後方互換）
    @State private var showReportSheet = false        // 通報シート表示フラグ
    @State private var navigateToProfile = false      // プロフィール画面へのナビゲーションフラグ
    @State private var showPostDetail = false         // 投稿詳細シートの表示状態
    @State private var showItemTags = false           // アイテムタグの表示/非表示
    @State private var postItems: [PostItem] = []     // Firestoreから取得した投稿アイテム
    @State private var itemsLoaded = false            // アイテムがロード済みか
    @State private var currentImageHeight: CGFloat = UIScreen.main.bounds.width  // 写真の可変高さ（初期値は画面幅でぺちゃんこ防止）
    @State private var isFirstImageLoaded: Bool = false  // 初回画像読み込み済みフラグ
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @ObservedObject private var blockService = BlockService.shared

    // postsViewModelから現在のいいね状態を動的に読み取る（UIが確実に更新されるため）
    private var postId: String { post.id ?? post.post_id }
    private var effectiveIsLiked: Bool { postsViewModel.likedPostIds.contains(postId) }
    private var effectiveLikes: Int {
        // posts配列またはsearchResults配列から最新のlikes_countを取得
        let currentPost = postsViewModel.posts.first(where: { ($0.id ?? $0.post_id) == postId })
            ?? postsViewModel.searchResults.first(where: { ($0.id ?? $0.post_id) == postId })
        return currentPost?.likes_count ?? post.likes_count
    }

    // 計算プロパティ: frontとbackの画像URLを(URL, side)のタプルで配列化
    private var imageEntries: [(url: String, side: String)] {
        var result: [(url: String, side: String)] = []
        if let f = post.image_url_front, !f.isEmpty { result.append((f, "front")) }
        if let b = post.image_url_back, !b.isEmpty { result.append((b, "back")) }
        return result
    }
    private var imageURLs: [String] { imageEntries.map { $0.url } }

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
        if blockService.isBlocked(post.user_id) {
            EmptyView()
        } else {
            cardContent
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card header
            NavigationLink(
                destination: ProfileView(userId: post.user_id)
                    .environmentObject(authViewModel)
                    .environmentObject(postsViewModel),
                isActive: $navigateToProfile
            ) {
                EmptyView()
            }
            HStack(spacing: 12) {
                Button {
                    navigateToProfile = true
                } label: {
                    HStack(spacing: 10) {
                        // Avatar
                        let avatarId = post.posterAvatarId ?? "zou"
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
                                    .font(.appFont(.regular, size: 20))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(avatarBg)
                        .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            // 1行目: 表示名 + グレーのユーザーID + 日記バッジ
                            HStack(spacing: 4) {
                                Text(post.posterDisplayName ?? "名前未設定")
                                    .font(.appFont(.bold, size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                if let uid = post.posterUniqueUserId, !uid.isEmpty {
                                    Text("@\(uid)")
                                        .font(.appFont(.medium, size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                // 日記バッジ
                                if post.is_calendar_post == true {
                                    HStack(spacing: 2) {
                                        Image(systemName: "book.closed")
                                            .font(.appFont(.regular, size: 8))
                                        Text("日記")
                                            .font(.appFont(.regular, size: 9))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.accentRed)
                                    .cornerRadius(4)
                                }
                            }
                            // 2行目: 子供名・性別・生後○ヶ月・地域・時刻
                            HStack(spacing: 4) {
                                if let name = post.posterChildAgeName, !name.isEmpty {
                                    Text(name)
                                        .lineLimit(1)
                                }
                                let genderStr = genderLabel(post.posterChildGender)
                                if !genderStr.isEmpty {
                                    Text("・\(genderStr)")
                                        .lineLimit(1)
                                }
                                Text("・\(ageLabel(months: post.child_age_months))")
                                    .lineLimit(1)
                                Text("・\(regionLabel(code: post.region_code))")
                                    .lineLimit(1)
                                Text("・\(timeAgo(ts: post.created_at))")
                                    .lineLimit(1)
                            }
                            .font(.appFont(.regular, size: 11))
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

            // Photo carousel with overlays (item tags, weather, actions)
            ZStack {
                photoCarousel

                // 左上: 天気（天気別うっすらカラー）
                VStack {
                    HStack {
                        weatherOverlayBadge
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                }

                // 右下: ♡（ピンク） + アイテム + 通報
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: onLike) {
                            HStack(spacing: 4) {
                                Image(systemName: effectiveIsLiked ? "heart.fill" : "heart")
                                    .foregroundColor(effectiveIsLiked ? .pink : .white)
                                Text("\(effectiveLikes)")
                                    .font(.appFont(.bold, size: 14))
                                    .foregroundColor(effectiveIsLiked ? .pink : .white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(effectiveIsLiked ? Color.pink.opacity(0.35) : Color.pink.opacity(0.25))
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)

                        if !(post.item_tags ?? []).isEmpty || (itemsLoaded && !postItems.isEmpty) {
                            Button {
                                if !itemsLoaded { loadItems() }
                                withAnimation(.easeInOut(duration: 0.2)) { showItemTags.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showItemTags ? "tag.fill" : "tag")
                                    Text("アイテム")
                                }
                                .font(.appFont(.bold, size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button {
                            showReportSheet = true
                        } label: {
                            Label("通報", systemImage: "exclamationmark.triangle")
                                .font(.appFont(.regular, size: 11))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.35))
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }

            // Untagged items list (items with no photo tag assigned)
            if showItemTags && itemsLoaded && !untaggedItems.isEmpty {
                untaggedItemsView
                    .transition(.opacity)
            }

            // Description
            if !post.description.isEmpty {
                Text(post.description)
                    .font(.appFont(.regular, size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 4)
            }

            // Footer spacer
            HStack {
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(
                targetType: .post,
                targetId: postId
            ) {
                postsViewModel.posts.removeAll { ($0.id ?? $0.post_id) == postId }
            }
        }
        .fullScreenCover(isPresented: $showPostDetail) {
            PostDetailView(
                post: post,
                postId: post.id ?? post.post_id,
                isLiked: effectiveIsLiked,
                onLike: onLike,
                onDeleted: { _ in }
            )
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
        }
        .onTapGesture {
            if !disableDetailSheet { showPostDetail = true }
        }
    }

    // MARK: - Photo Carousel
    // 説明: 投稿写真のカルーセル表示＋アイテムタグオーバーレイ

    private func imageSlide(uiImage: UIImage, entry: (url: String, side: String), geo: GeometryProxy) -> some View {
        let imgAspect = uiImage.size.height / uiImage.size.width
        let dispH = geo.size.width * imgAspect
        let clampedH = min(max(dispH, geo.size.width * 0.5), geo.size.width * 1.4)
        let tags = visibleTags(for: entry.side)
        // 枠が写真より大きい時の中央揃えオフセット
        let yOffset = max(0, (currentImageHeight - dispH) / 2)

        return ZStack(alignment: .topLeading) {
            // レターボックス用の薄めグレー背景
            Color(.systemGray5)

            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: currentImageHeight)

            ForEach(tags) { tag in
                itemTagDot(
                    item: postItems.indices.contains(tag.item_index) ? postItems[tag.item_index] : nil,
                    position: CGPoint(
                        x: CGFloat(tag.x_ratio) * geo.size.width,
                        y: yOffset + CGFloat(tag.y_ratio) * dispH
                    )
                )
            }
        }
        .frame(width: geo.size.width, height: currentImageHeight)
        .contentShape(Rectangle())
        .onAppear {
            // 初回は常に写真サイズに設定、それ以降は大きい方にのみ拡張（縮小はしない）
            if !isFirstImageLoaded {
                currentImageHeight = clampedH
                isFirstImageLoaded = true
            } else if clampedH > currentImageHeight {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentImageHeight = clampedH
                }
            }
        }
        .onTapGesture {
            if !itemsLoaded { loadItems() }
            withAnimation(.easeInOut(duration: 0.2)) { showItemTags.toggle() }
        }
    }

    // 計算プロパティ: 現在表示中の画像面（front/back）に対応するタグのみを抽出
    private func visibleTags(for side: String) -> [PostItemTag] {
        guard showItemTags && itemsLoaded else { return [] }
        let tags = (post.item_tags ?? []).filter { $0.image_side == side }
        print("[DEBUG] visibleTags for \(side): found \(tags.count) tags")
        for tag in tags {
            print("[DEBUG]   - item_index=\(tag.item_index), side=\(tag.image_side)")
        }
        return tags
    }

    // =============================================================================
    // 【Viewサマリー】photoCarousel
    // 目的: 投稿写真をTabViewでカルーセル表示し、アイテムタグをオーバーレイする
    // =============================================================================
    private var photoCarousel: some View {
        Group {
            if imageEntries.isEmpty {
                photoPlaceholder
            } else {
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(imageEntries.enumerated()), id: \.offset) { idx, entry in
                        GeometryReader { geo in
                            CachedAsyncImageWithSize(url: entry.url) { uiImage in
                                imageSlide(uiImage: uiImage, entry: entry, geo: geo)
                            } placeholder: {
                                Color(.systemGray5).overlay(ProgressView())
                                    .frame(width: geo.size.width, height: currentImageHeight)
                            }
                        }
                        .frame(height: currentImageHeight)
                        .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: imageEntries.count > 1 ? .always : .never))
                .frame(height: currentImageHeight)
                .onAppear { if !itemsLoaded { loadItems() } }
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
                        .font(.appFont(.medium, size: 11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(sizeLabel(item.size_value))
                        .font(.appFont(.regular, size: 10))
                        .foregroundColor(.white.opacity(0.95))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.65))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.3), radius: 2)
            }
        }
        .offset(x: position.x - 9, y: position.y - 9)
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
                let snap = try await db.collection("posts").document(postId).collection("items")
                    .order(by: "item_id")
                    .getDocuments()
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
            .frame(height: currentImageHeight)
            .overlay(
                Image(systemName: "photo")
                    .font(.appFont(.regular, size: 40))
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

    // 写真上に重ねる専用の天気バッジ（白文字+半透明黒背景）
    private var weatherOverlayBadge: some View {
        let wt = WeatherType(rawValue: post.weather_type)
        let bgColor: Color = {
            switch wt {
            case .sunny:  return Color.orange.opacity(0.35)
            case .cloudy: return Color.gray.opacity(0.35)
            case .rainy:  return Color.blue.opacity(0.35)
            case .snowy:  return Color.cyan.opacity(0.35)
            default:      return Color.black.opacity(0.35)
            }
        }()
        return Label("\(Int(post.temp_max))℃ / \(Int(post.temp_min))℃", systemImage: wt?.sfSymbol ?? "cloud.sun")
            .font(.appFont(.bold, size: 11))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bgColor)
            .cornerRadius(16)
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
    private func genderLabel(_ gender: Int?) -> String {
        switch gender {
        case 1: return "男の子"
        case 2: return "女の子"
        case 3: return "その他"
        default: return ""
        }
    }

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
        guard let idx = Int(code), idx >= 1, idx <= prefectures.count else { return "非公表" }
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
                        .font(.appFont(.medium, size: 12))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(sizeLabel(item.size_value))
                        .font(.appFont(.regular, size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    // 詳細ボタン
                    Button {
                        showPostDetail = true
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.appFont(.medium, size: 11))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentRed.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
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
            .font(.appFont(.bold, size: 11))
            .foregroundColor(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(bg)
            .cornerRadius(16)
    }
}

