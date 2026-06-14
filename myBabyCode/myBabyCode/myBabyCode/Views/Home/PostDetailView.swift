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
    let post: Post?                             // 表示対象の投稿データ（直接指定時）
    let postId: String?                          // 投稿ID（Firestoreから取得する場合）
    var isLiked: Bool = false                   // いいね済みかどうか
    var onLike: (() -> Void)? = nil             // いいね押下時のコールバック
    var onDeleted: ((Post) -> Void)? = nil      // 削除完了後のコールバック（オプション）
    
    // === postId指定時の状態 ===
    @State private var fetchedPost: Post? = nil  // Firestoreから取得した投稿
    @State private var isLoading = false         // ロード中フラグ

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
    @State private var imageHeights: [Int: CGFloat] = [:]  // 各画像インデックス→実際の表示高さ

    // 通報関連
    @State private var showReportSheet = false      // 投稿通報シート表示フラグ

    // 投稿編集関連
    @State private var showPostEditor = false       // 投稿編集画面（NewPostView）表示フラグ
    @State private var showStampEditor = false      // スタンプ編集画面表示フラグ（旧、互換用）
    @State private var editingImage: UIImage? = nil // 編集中の画像
    @State private var editingImageSide: String = "front" // 編集中の画像面
    @State private var isLoadingImage = false       // 画像読み込み中フラグ

    // 実際に表示する投稿データ
    private var displayPost: Post? {
        post ?? fetchedPost
    }
    
    // postsViewModelから現在のいいね状態を動的に読み取る（シート表示中でもUIが確実に更新されるため）
    private var effectivePostId: String { displayPost?.id ?? displayPost?.post_id ?? postId ?? "" }
    private var effectiveIsLiked: Bool { postsViewModel.likedPostIds.contains(effectivePostId) }
    private var effectiveLikes: Int {
        // posts配列またはsearchResults配列から最新のlikes_countを取得
        let currentPost = postsViewModel.posts.first(where: { ($0.id ?? $0.post_id) == effectivePostId })
            ?? postsViewModel.searchResults.first(where: { ($0.id ?? $0.post_id) == effectivePostId })
        return currentPost?.likes_count ?? displayPost?.likes_count ?? 0
    }

    // 自分の投稿かどうか
    private var isMyPost: Bool {
        displayPost?.user_id == authViewModel.currentUser?.user_id
    }

    // 計算プロパティ: 現在表示中の画像面に対応するタグのみ抽出
    private var visibleItemTags: [PostItemTag] {
        guard showItemTags && itemsLoaded else { return [] }
        let side = currentImageIndex == 0 ? "front" : "back"
        return (displayPost?.item_tags ?? []).filter { $0.image_side == side }
    }

    // 計算プロパティ: frontとbackの画像URLを配列化
    private var imageURLs: [String] {
        guard let p = displayPost else { return [] }
        return [p.image_url_front, p.image_url_back].compactMap { $0 }.filter { !$0.isEmpty }
    }

    private var carouselH: CGFloat {
        imageHeights[currentImageIndex] ?? UIScreen.main.bounds.width
    }

    private func imageCarousel(availableWidth: CGFloat) -> some View {
        let carH = imageHeights[currentImageIndex] ?? availableWidth
        return TabView(selection: $currentImageIndex) {
            ForEach(imageURLs.indices, id: \.self) { idx in
                CachedAsyncImageWithSize(url: imageURLs[idx]) { uiImage in
                    detailImageSlide(uiImage: uiImage, idx: idx, screenW: availableWidth)
                        .onAppear {
                            let h = availableWidth * uiImage.size.height / uiImage.size.width
                            if imageHeights[idx] != h { imageHeights[idx] = h }
                        }
                } placeholder: {
                    Color(.systemGray5).overlay(ProgressView())
                        .frame(width: availableWidth, height: availableWidth)
                }
                .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: imageURLs.count > 1 ? .always : .never))
        .frame(width: availableWidth, height: carH)
        .animation(.easeInOut(duration: 0.2), value: carH)
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
            GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // ロード中または投稿データがない場合
                    if isLoading {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 100)
                            ProgressView()
                            Text("読み込み中...")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else if displayPost == nil {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 100)
                            Image(systemName: "exclamationmark.triangle")
                                .font(.appFont(.regular, size: 48))
                                .foregroundColor(.secondary)
                            Text("投稿が見つかりません")
                                .font(.appFont(.regular, size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        // 投稿データ表示
                        let p = displayPost!
                        
                        // Photo carousel
                        if imageURLs.isEmpty {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color.ecruBackground)
                                .frame(height: UIScreen.main.bounds.width)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.appFont(.regular, size: 48))
                                        .foregroundColor(.secondary.opacity(0.4))
                                )
                        } else {
                            imageCarousel(availableWidth: geo.size.width)
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            // Poster info + Like button
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.posterDisplayName ?? "名前未設定")
                                        .font(.appFont(.bold, size: 15))
                                    HStack(spacing: 6) {
                                        if let childName = p.posterChildAgeName, !childName.isEmpty {
                                            Text(childName)
                                                .font(.appFont(.medium, size: 12))
                                                .foregroundColor(.secondary)
                                            Text("・")
                                                .font(.appFont(.regular, size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        Text(ageLabel(months: p.child_age_months))
                                            .font(.appFont(.regular, size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                // Like button
                                Button {
                                    onLike?()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: effectiveIsLiked ? "heart.fill" : "heart")
                                            .font(.appFont(.regular, size: 20))
                                            .foregroundColor(effectiveIsLiked ? .red : .gray)
                                        Text("\(effectiveLikes)")
                                            .font(.appFont(.regular, size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            // Weather / Temp
                            let wt = WeatherType(rawValue: p.weather_type)
                            HStack(spacing: 8) {
                                Label(wt?.label ?? "", systemImage: wt?.sfSymbol ?? "cloud.sun")
                                    .font(.appFont(.medium, size: 13))
                                    .foregroundColor(.blue)
                                Spacer()
                                Text("最高 \(Int(p.temp_max))℃  最低 \(Int(p.temp_min))℃")
                                    .font(.appFont(.regular, size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .padding(12)
                            .background(Color.blue.opacity(0.07))
                            .cornerRadius(12)

                            // Region
                            let region: String = {
                                guard let idx = Int(p.region_code), idx >= 1, idx <= prefectures.count else { return "非公表" }
                                return prefectures[idx - 1]
                            }()
                            Label(region, systemImage: "mappin.and.ellipse")
                                .font(.appFont(.regular, size: 13))
                                .foregroundColor(.secondary)

                            // Description
                            if !p.description.isEmpty {
                                Text(p.description)
                                    .font(.appFont(.regular, size: 15))
                                    .foregroundColor(.primary)
                            }

                            // Items
                            if itemsLoaded && !postItems.isEmpty {
                                itemsSection
                            }
                        }
                        .padding(20)

                        // バナー広告（設定画面からサブスク登録で非表示可）
                        AdBannerView()
                    }
                }
            }
            } // GeometryReader
            .task { 
                await fetchPostIfNeeded()
                await loadItems()
            }
            .navigationTitle("投稿詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if isMyPost {
                            Button {
                                showPostEditor = true
                            } label: {
                                Label("投稿を編集", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                showReportSheet = true
                            } label: {
                                Label("通報する", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting)
                }
            }
            .sheet(isPresented: $showPostEditor) {
                if let p = displayPost {
                    NewPostView(editingPost: p)
                }
            }
            .sheet(isPresented: $showReportSheet) {
                ReportSheetView(
                    targetType: .post,
                    targetId: effectivePostId
                ) {
                    dismiss()
                }
            }
            .alert("投稿を削除", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    Task {
                        guard let p = displayPost else { return }
                        isDeleting = true
                        let success = await postsViewModel.deletePost(p)
                        isDeleting = false
                        if success {
                            onDeleted?(p)
                            dismiss()
                        }
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この投稿を削除しますか？この操作は取り消せません。")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("アイテム")
                .font(.appFont(.bold, size: 15))

            ForEach(postItems.indices, id: \.self) { idx in
                let item = postItems[idx]
                let tags = (displayPost?.item_tags ?? []).filter { $0.item_index == idx }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.custom_name)
                                .font(.appFont(.medium, size: 14))
                                .foregroundColor(.primary)
                            Text(item.category)
                                .font(.appFont(.regular, size: 11))
                                .foregroundColor(.accentGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentGreen.opacity(0.1))
                                .cornerRadius(6)
                        }
                        Spacer()
                        Text(sizeLabel(item.size_value))
                            .font(.appFont(.medium, size: 13))
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
                                        .font(.appFont(.regular, size: 11))
                                        .foregroundColor(.pink)
                                    Text(tag.image_side == "front" ? "フロント" : "バック")
                                        .font(.appFont(.regular, size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.pink.opacity(0.08))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // アフィリエイトリンク（楽天・Amazon）
                    AffiliateLinkRow(item: item)
                }
                .padding(12)
                .background(Color.white)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    // Firestoreから投稿を取得（postId指定時）
    private func fetchPostIfNeeded() async {
        guard post == nil, let pid = postId else { return }
        isLoading = true
        defer { isLoading = false }
        
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("posts").document(pid).getDocument()
            if let p = try? doc.data(as: Post.self) {
                fetchedPost = p
            }
        } catch {
            print("[PostDetailView] Failed to fetch post: \(error)")
        }
    }
    
    private func loadItems() async {
        guard let p = displayPost else {
            itemsLoaded = true
            return
        }
        let pid = p.id ?? p.post_id
        guard !pid.isEmpty else {
            itemsLoaded = true
            return
        }
        let db = Firestore.firestore()
        do {
            let snap = try await db.collection("posts").document(pid).collection("items")
                .order(by: "item_id")
                .getDocuments()
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

    // =============================================================================
    // 【関数サマリー】openStampEditor
    // 目的: 現在表示中の画像をダウンロードしてスタンプ編集画面を開く
    // =============================================================================
    private func openStampEditor() async {
        isLoadingImage = true
        defer { isLoadingImage = false }

        let imageUrl = currentImageIndex == 0 ? displayPost?.image_url_front : displayPost?.image_url_back
        let side = currentImageIndex == 0 ? "front" : "back"

        guard let urlString = imageUrl, let url = URL(string: urlString) else {
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                editingImage = image
                editingImageSide = side
                showStampEditor = true
            }
        } catch {
            print("[PostDetailView] Failed to load image: \(error)")
        }
    }

    // =============================================================================
    // 【関数サマリー】updateStamps
    // 目的: 編集したスタンプをFirestoreに保存
    // =============================================================================
    private func updateStamps(stamps: [PostStamp]) async {
        guard let p = displayPost else { return }
        let pid = p.id ?? p.post_id
        guard !pid.isEmpty else { return }

        let db = Firestore.firestore()
        let postRef = db.collection("posts").document(pid)

        // 既存のスタンプから、編集対象面以外のスタンプを保持
        let otherSideStamps = p.stamps?.filter { $0.image_side != editingImageSide } ?? []
        let allStamps = otherSideStamps + stamps

        let stampData = allStamps.map { stamp -> [String: Any] in
            return [
                "id": stamp.id,
                "kind_type": stamp.kind_type,
                "kind_value": stamp.kind_value,
                "x_ratio": stamp.x_ratio,
                "y_ratio": stamp.y_ratio,
                "scale": stamp.scale,
                "rotation": stamp.rotation,
                "image_side": stamp.image_side
            ]
        }

        do {
            try await postRef.updateData(["stamps": stampData])
            print("[PostDetailView] Stamps updated successfully")
        } catch {
            print("[PostDetailView] Failed to update stamps: \(error)")
        }
    }

    // MARK: - Detail Image Slide

    private func detailImageSlide(uiImage: UIImage, idx: Int, screenW: CGFloat) -> some View {
        let dispH = screenW * uiImage.size.height / uiImage.size.width
        let side = idx == 0 ? "front" : "back"
        let tags: [PostItemTag] = showItemTags ? (displayPost?.item_tags ?? []).filter { $0.image_side == side } : []
        return ZStack(alignment: .topLeading) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: screenW, height: dispH)
            ForEach(tags) { tag in
                itemTagDot(
                    item: postItems.indices.contains(tag.item_index) ? postItems[tag.item_index] : nil,
                    position: CGPoint(
                        x: CGFloat(tag.x_ratio) * screenW,
                        y: CGFloat(tag.y_ratio) * dispH
                    )
                )
            }
        }
        .frame(width: screenW, height: dispH)
        .contentShape(Rectangle())
        .onTapGesture {
            if !itemsLoaded { Task { await loadItems() } }
            withAnimation(.easeInOut(duration: 0.2)) {
                showItemTags.toggle()
            }
        }
    }

    // MARK: - Item Tag Dot

    @ViewBuilder
    private func itemTagDot(item: PostItem?, position: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // White dot（この中心がposition座標に一致する）
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.35), radius: 3)
                Circle()
                    .strokeBorder(Color.accentRed.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }

            // Label with brand and size（ドットの下に表示）
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
}

