// =============================================================================
// ファイル名: HomeView.swift
// 役割: ホーム画面（タイムライン）の表示・タブ切り替え・無限スクロール
// 説明:
//   アプリのメインとなる投稿タイムライン画面です。上部にアプリヘッダーと
//   「新着/おすすめ/フォロー中」の3タブを持ち、選択に応じた投稿リストを
//   LazyVStackで表示します。Pull-to-refresh（下に引っ張って更新）と
//   無限スクロール（最後の要素までスクロールで次ページ取得）をサポートしています。
// =============================================================================

import SwiftUI

struct HomeView: View {
    // === 環境オブジェクト ===
    @EnvironmentObject var postsViewModel: PostsViewModel  // 投稿データ・タブ状態
    @EnvironmentObject var authViewModel: AuthViewModel    // ログインユーザー情報（おすすめ絞り込みに使用）

    // === サブスクリプション（広告非表示判定）===
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // アフィリエイトカードを何件ごとに挿入するか
    private let affiliateInsertInterval: Int = 5

    // ロゴタップ時にトップへスクロールさせるためのトリガー変数
    @State private var scrollToTopFlag = false

    // 表示モード: リスト表示 / グリッド表示
    @State private var isGridMode: Bool = false
    @State private var selectedPost: Post? = nil  // グリッド表示時の詳細画面用

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: ホーム画面の全体レイアウトを定義
    // 構成:
    //   1. AppHeaderView（ロゴタップでトップへスクロール＋検索アイコン）
    //   2. TimelineTabBar（新着/おすすめ/フォロー中タブ切り替え）
    //   3. 投稿フィード:
    //      - isLoading → ProgressView
    //      - postsが空 → 「投稿がありません」プレースホルダー
    //      - それ以外 → ScrollView + LazyVStack + ForEach(PostCardView)
    //   4. .refreshable で下に引っ張って更新
    //   5. .task で画面表示時に初回データ取得
    // =============================================================================
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {

                // ヘッダー: アプリロゴ＋検索アイコン
                AppHeaderView(
                    onLogoTap: { scrollToTopFlag.toggle() },
                    showSearchButton: true
                )

                // タブセレクター: 新着 / おすすめ / フォロー中 + 表示モード切り替え
                HStack(spacing: 12) {
                    TimelineTabBar(selected: $postsViewModel.currentTab)
                    
                    // 表示モード切り替えボタン
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isGridMode.toggle()
                        }
                    } label: {
                        Image(systemName: isGridMode ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 18))
                            .foregroundColor(.accentRed)
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // フィード表示エリア
                if postsViewModel.isLoading {
                    // 初回読み込み中
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if postsViewModel.posts.isEmpty {
                    // 投稿がない場合の空状態
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("投稿がありません")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    // 投稿表示（リスト or グリッド）
                    if isGridMode {
                        gridPostsView
                    } else {
                        listPostsView
                    }
                }
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            // 画面初回表示時に投稿といいねデータを取得
            .task {
                await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                await postsViewModel.fetchLikedPosts()
            }
            // タブ切り替え時に投稿を再取得
            .onChange(of: postsViewModel.currentTab) { _ in
                Task {
                    await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                }
            }
            // 投稿詳細シート（グリッド表示時）
            .sheet(item: $selectedPost) { post in
                PostDetailView(
                    post: post,
                    isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                    onLike: { Task { await postsViewModel.toggleLike(post: post) } },
                    onDeleted: { _ in }
                )
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
            }
        }
    }
    
    // MARK: - List View
    
    private var listPostsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // トップスクロール用の目印
                    Color.clear.frame(height: 0).id("homeTop")
                    ForEach(postsViewModel.posts.indices, id: \.self) { idx in
                        let post = postsViewModel.posts[idx]

                        PostCardView(
                            post: post,
                            isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                            onLike: {
                                Task { await postsViewModel.toggleLike(post: post) }
                            },
                            onReport: {
                                Task { await postsViewModel.report(post: post) }
                            }
                        )
                        // 最後の要素が表示されたら次ページを取得（無限スクロール）
                        .onAppear {
                            if post.post_id == postsViewModel.posts.last?.post_id {
                                Task { await postsViewModel.fetchMorePosts(user: authViewModel.currentUser) }
                            }
                        }

                        // N件ごとにアフィリエイトカードを挿入（サブスク未加入時のみ）
                        // TODO: 楽天・Amazon アフィリエイトID設定後に自動で有効になります
                        if !subscriptionManager.isAdsRemoved && (idx + 1) % affiliateInsertInterval == 0 {
                            AffiliateTimelineCard(keyword: post.posterDisplayName ?? "子供服")
                        }
                    }
                    // さらに読み込める場合は下部にProgressView
                    if postsViewModel.hasMorePosts {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 12)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            // Pull-to-refresh: 画面を下に引っ張って更新
            .refreshable {
                await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                await postsViewModel.fetchLikedPosts()
            }
            // ロゴタップでトップへスクロール
            .onChange(of: scrollToTopFlag) { _ in
                withAnimation { proxy.scrollTo("homeTop") }
            }
        }
    }
    
    // MARK: - Grid View (3 columns)
    
    private var gridPostsView: some View {
        let cellSize = (UIScreen.main.bounds.width - 32 - 16) / 3 // 左右16px padding + 間隔8px
        let columns = [
            GridItem(.fixed(cellSize), spacing: 8),
            GridItem(.fixed(cellSize), spacing: 8),
            GridItem(.fixed(cellSize), spacing: 8)
        ]
        
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // トップスクロール用の目印
                    Color.clear.frame(height: 0).id("homeTop")
                    
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(postsViewModel.posts, id: \.post_id) { post in
                            MiniPostCardView(
                                post: post,
                                isLiked: postsViewModel.likedPostIds.contains(post.id ?? post.post_id),
                                onLike: {
                                    Task { await postsViewModel.toggleLike(post: post) }
                                },
                                onTap: {
                                    selectedPost = post
                                }
                            )
                            .frame(width: cellSize, height: cellSize * 1.3)
                            // 最後の要素が表示されたら次ページを取得（無限スクロール）
                            .onAppear {
                                if post.post_id == postsViewModel.posts.last?.post_id {
                                    Task { await postsViewModel.fetchMorePosts(user: authViewModel.currentUser) }
                                }
                            }
                        }
                    }
                    
                    // さらに読み込める場合は下部にProgressView
                    if postsViewModel.hasMorePosts {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            // Pull-to-refresh: 画面を下に引っ張って更新
            .refreshable {
                await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                await postsViewModel.fetchLikedPosts()
            }
            // ロゴタップでトップへスクロール
            .onChange(of: scrollToTopFlag) { _ in
                withAnimation { proxy.scrollTo("homeTop") }
            }
        }
    }
}

// =============================================================================
// MARK: - AppHeaderView
// 役割: ホーム画面上部のアプリヘッダー（ロゴ＋検索アイコン）
// =============================================================================

struct AppHeaderView: View {
    var onLogoTap: (() -> Void)? = nil   // ロゴタップ時のコールバック（オプション）
    var showSearchButton: Bool = true     // 検索アイコンの表示フラグ

    var body: some View {
        ZStack {
            // 中央: ロゴ画像（タップ可能）
            Button {
                onLogoTap?()
            } label: {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 24)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            // 右端: 検索アイコン（NavigationLinkでSearchViewへ遷移）
            if showSearchButton {
                HStack {
                    Spacer()
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.accentRed)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
        )
    }
}

// =============================================================================
// MARK: - TimelineTabBar
// 役割: 「新着/おすすめ/フォロー中」のタブ選択UI
// =============================================================================

struct TimelineTabBar: View {
    @Binding var selected: TimelineTab   // 選択中のタブ（PostsViewModelと双方向バインディング）

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimelineTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: selected == tab ? .bold : .regular))
                            .foregroundColor(selected == tab ? .accentRed : .gray)
                            .padding(.vertical, 8)
                        // 選択中のタブのみ下線（朱色）を表示
                        Rectangle()
                            .fill(selected == tab ? Color.accentRed : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.ecruBackground)
        .cornerRadius(12)
    }
}

