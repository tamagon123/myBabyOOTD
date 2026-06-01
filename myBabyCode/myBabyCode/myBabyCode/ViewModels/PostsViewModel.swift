// =============================================================================
// ファイル名: PostsViewModel.swift
// 役割: 投稿（タイムライン・いいね・通報・新規投稿・削除）と下書きの管理
// 説明:
//   このクラスはアプリ内の「投稿に関するすべての処理」を担当します。
//   タイムラインの取得（新着/おすすめ/フォロー中）、いいねの切り替え、
//   投稿の通報・非表示化、新規投稿の作成（画像アップロード＋Firestore保存）、
//   投稿削除などを行います。画面（View）と連携するため@Publishedプロパティで
//   UIに変更を自動通知します。また、投稿作成時の下書き管理（DraftManager）も
//   同ファイル内で定義されています。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Combine

// TimelineTab: ホーム画面の3つのタブ（新着・おすすめ・フォロー中）を表す列挙型。
// CaseIterableにより、全ケースを自動で配列化できる（TimelineTabBarで使用）。
enum TimelineTab: String, CaseIterable, Identifiable {
    case latest   = "新着"
    case recommend = "おすすめ"
    case following = "フォロー中"
    var id: String { rawValue }
}

// PostFilterType: 絞り込み検索の表示タイプ
enum PostFilterType: String, CaseIterable, Identifiable {
    case postsOnly = "投稿のみ"
    case diaryOnly = "日記のみ"
    case all = "投稿+日記"
    var id: String { rawValue }
}

// MARK: - Array Extension for Chunking
// 説明: Firestoreの「in」クエリは最大30件までしか指定できないため、
//       フォロー中ユーザーIDなどを30件ずつのチャンクに分割するために使用される。

extension Array {
    // =============================================================================
    // 【関数サマリー】chunked
    // 目的: 配列を指定サイズの小さな配列（チャンク）に分割する
    // 引数:
    //   - size: Int - 1チャンクあたりの最大要素数
    // 戻り値: [[Element]] - チャンク化された2次元配列
    // 呼び出し元: fetchFollowingPosts()（フォロー中IDを30件ずつに分割）
    // =============================================================================
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

@MainActor
class PostsViewModel: ObservableObject {
    // === UI状態通知用プロパティ ===
    @Published var posts: [Post] = []               // 現在表示中の投稿リスト
    @Published var isLoading = false                // データ読み込み中フラグ
    @Published var errorMessage: String?            // エラーメッセージ
    @Published var currentTab: TimelineTab = .latest  // 選択中のタイムラインタブ
    @Published var likedPostIds: Set<String> = []     // 自分がいいねした投稿IDの集合
    @Published var pendingItemTags: [PostItemTag] = [] // 新規投稿時に一時保持されるタグ位置
    @Published var hasMorePosts: Bool = false        // さらに読み込める投稿があるか
    @Published var searchResults: [Post] = []        // 検索結果の投稿リスト
    @Published var isSearchActive: Bool = false       // 検索結果表示中フラグ
    @Published var searchFilter: PostFilterType = .postsOnly  // 絞り込み検索フィルター

    // === プライベート状態 ===
    private let db = Firestore.firestore()          // Firestoreデータベース参照
    private let storage = Storage.storage()          // Firebase Storage参照
    private var lastDocument: QueryDocumentSnapshot? = nil  // ページネーション用カーソル
    private var followingCursor: Timestamp? = nil     // フォロータブのページネーション用
    private var cachedFollowingIds: [String] = []   // フォロー中ユーザーIDのキャッシュ
    private let pageSize: Int = 20                  // 1ページあたりの取得件数

    // =============================================================================
    // 【関数サマリー】clearSearch
    // 目的: 検索結果をクリアして通常のタイムライン表示に戻す
    // =============================================================================
    func clearSearch() {
        isSearchActive = false
        searchResults = []
    }

    // MARK: - Fetch
    // 説明: タイムライン投稿の取得系処理

    // =============================================================================
    // 【関数サマリー】fetchPosts
    // 目的: 現在選択中のタブに応じた投稿リストをFirestoreから取得する（初回・リフレッシュ用）
    // 引数:
    //   - user: AppUser? - ログイン中のユーザー（おすすめタブの絞り込みに使用）
    // 戻り値: なし
    // 処理の流れ:
    //   1. ページネーション状態をリセット
    //   2. currentTabに応じてFirestoreクエリを構築
    //      - latest: 全投稿を新着順
    //      - recommend: 同地域＆±3ヶ月の年齢範囲で絞り込み
    //      - following: フォロー中ユーザーの投稿を取得
    //   3. enrichWithPosterInfo()で投稿者情報を付加
    //   4. posts配列にセットしUI更新
    // 呼び出し元: HomeView.task, HomeView.refreshable, HomeView.onChange(currentTab)
    // =============================================================================
    func fetchPosts(user: AppUser?) async {
        guard !isLoading else {
            print("[DEBUG] fetchPosts skipped: already loading")
            return
        }
        print("[DEBUG] fetchPosts started, current posts count: \(posts.count)")
        isLoading = true
        do {
            lastDocument = nil
            followingCursor = nil
            hasMorePosts = false
            var query: Query = db.collection("posts")
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .limit(to: pageSize)

            switch currentTab {
            case .latest:
                break
            case .recommend:
                if let user = user {
                    let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
                    let lower = max(0, ageMonths - 3)
                    let upper = ageMonths + 3
                    query = db.collection("posts")
                        .whereField("is_hidden", isEqualTo: false)
                        .whereField("region_code", isEqualTo: user.region_code)
                        .whereField("child_age_months", isGreaterThanOrEqualTo: lower)
                        .whereField("child_age_months", isLessThanOrEqualTo: upper)
                        .order(by: "child_age_months")
                        .order(by: "created_at", descending: true)
                        .limit(to: pageSize)
                }
            case .following:
                guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { break }
                let followSnaps = try await db.collection("follows")
                    .whereField("follower_id", isEqualTo: uid)
                    .getDocuments()
                let followingIds = followSnaps.documents.compactMap { $0.data()["following_id"] as? String }
                cachedFollowingIds = followingIds
                guard !followingIds.isEmpty else {
                    posts = []
                    isLoading = false
                    return
                }
                var followPage = try await fetchFollowingPosts(ids: followingIds)
                // カレンダー投稿（日記）はタイムラインに表示しない
                followPage = followPage.filter { !($0.is_calendar_post ?? false) }
                let enrichedFollow = await enrichWithPosterInfo(followPage)
                posts = enrichedFollow
                followingCursor = enrichedFollow.last?.created_at
                hasMorePosts = followPage.count == pageSize
                isLoading = false
                return
            }

            let snapshot = try await query.getDocuments()
            var fetched = try snapshot.documents.map { try $0.data(as: Post.self) }
            // カレンダー投稿（日記）はタイムラインに表示しない（通常投稿のみ）
            fetched = fetched.filter { !($0.is_calendar_post ?? false) }
            fetched = await enrichWithPosterInfo(fetched)
            posts = fetched
            let postIds = fetched.map { $0.post_id }
            let uniqueIds = Set(postIds)
            print("[DEBUG] fetchPosts completed: fetched=\(fetched.count), uniqueIDs=\(uniqueIds.count), posts=\(posts.count)")
            if uniqueIds.count != fetched.count {
                print("[DEBUG] WARNING: Duplicate post IDs detected!")
            }
            lastDocument = snapshot.documents.last
            hasMorePosts = snapshot.documents.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // =============================================================================
    // 【関数サマリー】fetchMorePosts
    // 目的: タイムラインの次ページを取得して既存リストに追加する（無限スクロール用）
    // 引数:
    //   - user: AppUser? - ログイン中のユーザー
    // 戻り値: なし
    // 処理の流れ:
    //   1. hasMorePosts==falseまたは既に読み込み中なら早期リターン
    //   2. currentTabに応じてFirestoreのstart(afterDocument:)で次ページを取得
    //   3. 取得した投稿をposts配列にappend（既存データに追加）
    // 呼び出し元: HomeViewのScrollView内、最後のPostCardView.onAppear
    // =============================================================================
    func fetchMorePosts(user: AppUser?) async {
        guard hasMorePosts, !isLoading, let lastDoc = lastDocument else { return }
        print("[DEBUG] fetchMorePosts started, current posts count: \(posts.count)")
        isLoading = true
        defer { isLoading = false }
        do {
            var query: Query
            switch currentTab {
            case .latest:
                query = db.collection("posts")
                    .whereField("is_hidden", isEqualTo: false)
                    .order(by: "created_at", descending: true)
                    .start(afterDocument: lastDoc)
                    .limit(to: pageSize)
            case .recommend:
                if let user = user {
                    let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
                    let lower = max(0, ageMonths - 3)
                    let upper = ageMonths + 3
                    query = db.collection("posts")
                        .whereField("is_hidden", isEqualTo: false)
                        .whereField("region_code", isEqualTo: user.region_code)
                        .whereField("child_age_months", isGreaterThanOrEqualTo: lower)
                        .whereField("child_age_months", isLessThanOrEqualTo: upper)
                        .order(by: "child_age_months")
                        .order(by: "created_at", descending: true)
                        .start(afterDocument: lastDoc)
                        .limit(to: pageSize)
                } else { return }
            case .following:
                guard !cachedFollowingIds.isEmpty, let cursor = followingCursor else { return }
                var followPage = try await fetchFollowingPosts(ids: cachedFollowingIds, before: cursor)
                // カレンダー投稿（日記）はタイムラインに表示しない
                followPage = followPage.filter { !($0.is_calendar_post ?? false) }
                let enrichedFollow = await enrichWithPosterInfo(followPage)
                print("[DEBUG] fetchMorePosts (following): appending \(enrichedFollow.count) posts")
                posts.append(contentsOf: enrichedFollow)
                followingCursor = enrichedFollow.last?.created_at
                hasMorePosts = followPage.count == pageSize
                return
            }
            let snapshot = try await query.getDocuments()
            var fetched = try snapshot.documents.map { try $0.data(as: Post.self) }
            // カレンダー投稿（日記）はタイムラインに表示しない
            fetched = fetched.filter { !($0.is_calendar_post ?? false) }
            fetched = await enrichWithPosterInfo(fetched)
            print("[DEBUG] fetchMorePosts: appending \(fetched.count) posts, lastDoc=\(lastDoc.documentID)")
            posts.append(contentsOf: fetched)
            lastDocument = snapshot.documents.last
            hasMorePosts = snapshot.documents.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Following helpers
    // 説明: フォロー中タブ専用の補助関数群

    // =============================================================================
    // 【関数サマリー】fetchFollowingPosts
    // 目的: フォロー中のユーザーIDリストから、それらのユーザーの投稿を並列で取得する
    // 引数:
    //   - ids: [String] - フォロー中ユーザーのUID配列
    //   - cursor: Timestamp? - ページネーション用の取得開始位置（前回最後のcreated_at）
    // 戻り値: [Post] - 取得した投稿リスト（新着順・最大pageSize件）
    // 処理の流れ:
    //   1. idsを30件ずつのチャンクに分割（Firestoreのinクエリ上限対策）
    //   2. withThrowingTaskGroupで各チャンクを並列クエリ
    //   3. 結果を統合しcreated_at降順でソート
    //   4. pageSize件に制限して返却
    // 呼び出し元: fetchPosts(), fetchMorePosts()
    // 備考: Firestoreの「in」クエリは最大30要素までなのでchunkedが必須。
    // =============================================================================
    private func fetchFollowingPosts(ids: [String], before cursor: Timestamp? = nil) async throws -> [Post] {
        let chunks = ids.chunked(into: 30)
        var allPosts: [Post] = []
        try await withThrowingTaskGroup(of: [Post].self) { group in
            for chunk in chunks {
                group.addTask {
                    let snap: QuerySnapshot
                    if let cursor = cursor {
                        snap = try await self.db.collection("posts")
                            .whereField("is_hidden", isEqualTo: false)
                            .whereField("user_id", in: chunk)
                            .whereField("created_at", isLessThan: cursor)
                            .order(by: "created_at", descending: true)
                            .limit(to: self.pageSize)
                            .getDocuments()
                        return try await MainActor.run { try snap.documents.map { try $0.data(as: Post.self) } }
                    } else {
                        snap = try await self.db.collection("posts")
                            .whereField("is_hidden", isEqualTo: false)
                            .whereField("user_id", in: chunk)
                            .order(by: "created_at", descending: true)
                            .limit(to: self.pageSize)
                            .getDocuments()
                        return try await MainActor.run { try snap.documents.map { try $0.data(as: Post.self) } }
                    }
                }
            }
            for try await result in group {
                allPosts.append(contentsOf: result)
            }
        }
        return Array(allPosts
            .sorted { $0.created_at.seconds > $1.created_at.seconds }
            .prefix(pageSize))
    }

    // =============================================================================
    // 【関数サマリー】enrichWithPosterInfo
    // 目的: 投稿リストに対して、各投稿者の表示情報（アバター・名前）を並列で取得・付与する
    // 引数:
    //   - posts: [Post] - 投稿者情報が未設定の生の投稿リスト
    // 戻り値: [Post] - posterAvatarId / posterAvatarBgColor / posterDisplayName が埋められた投稿リスト
    // 処理の流れ:
    //   1. 投稿リストから重複のないuser_id一覧を抽出
    //   2. withTaskGroupで各user_idのFirestore usersドキュメントを並列取得
    //   3. userMap（辞書）にuser_idをキーとして情報を蓄積
    //   4. 各Postに対応する投稿者情報をコピーして返却
    // 呼び出し元: fetchPosts(), fetchMorePosts(), fetchFollowingPosts()
    // 備考: これがないとタイムライン上で投稿者のアバターと名前が表示されない。
    // =============================================================================
    private func enrichWithPosterInfo(_ posts: [Post]) async -> [Post] {
        let userIds = Array(Set(posts.map { $0.user_id }))
        var userMap: [String: (avatarId: String, avatarBgColor: String?, displayName: String?, uniqueUserId: String?, children: [[String: Any]]?)] = [:]
        await withTaskGroup(of: (String, String, String?, String?, String?, [[String: Any]]?)?.self) { group in
            for uid in userIds {
                group.addTask {
                    guard let snap = try? await Firestore.firestore().collection("users").document(uid).getDocument(),
                          let data = snap.data() else { return nil }
                    let avatarId = data["avatar_id"] as? String ?? "bear"
                    let avatarBgColor = data["avatar_bg_color"] as? String
                    let displayName = (data["display_name"] as? String) ?? (data["unique_user_id"] as? String)
                    let uniqueUserId = data["unique_user_id"] as? String
                    let children = data["children"] as? [[String: Any]]
                    return (uid, avatarId, avatarBgColor, displayName, uniqueUserId, children)
                }
            }
            for await result in group {
                if let (uid, avatarId, avatarBgColor, displayName, uniqueUserId, children) = result {
                    userMap[uid] = (avatarId, avatarBgColor, displayName, uniqueUserId, children)
                }
            }
        }
        return posts.map { post in
            var p = post
            if let info = userMap[post.user_id] {
                p.posterAvatarId = info.avatarId
                p.posterAvatarBgColor = info.avatarBgColor
                p.posterDisplayName = info.displayName
                p.posterUniqueUserId = info.uniqueUserId
                // 子供名・性別: children配列の最初の子供の情報を使う
                if let children = info.children, let firstChild = children.first {
                    p.posterChildAgeName = firstChild["name"] as? String
                    p.posterChildGender = firstChild["gender"] as? Int
                }
            }
            return p
        }
    }

    // =============================================================================
    // 【関数サマリー】fetchLikedPosts
    // 目的: 現在ログイン中のユーザーが「いいね」した投稿IDの集合をFirestoreから取得する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. likesコレクションでuser_id==自分のドキュメントを全取得
    //   2. post_idフィールドを抽出してSet<String>に変換
    //   3. likedPostIdsにセット（PostCardViewのハート表示判定に使用）
    // 呼び出し元: HomeView.task（画面表示時）, HomeView.refreshable（引っ張り更新時）
    // =============================================================================
    func fetchLikedPosts() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("likes")
                .whereField("user_id", isEqualTo: uid)
                .getDocuments()
            likedPostIds = Set(snap.documents.compactMap { $0.data()["post_id"] as? String })
        } catch {}
    }

    // MARK: - Like
    // 説明: いいね（ハート）の切り替え処理

    // =============================================================================
    // 【関数サマリー】toggleLike
    // 目的: 指定した投稿のいいね状態をトグル（ON→OFF または OFF→ON）する
    // 引数:
    //   - post: Post - 対象の投稿データ
    // 戻り値: なし
    // 処理の流れ:
    //   1. likedPostIdsに含まれる → いいね解除
    //      - likes/{uid}_{postId} を削除
    //      - posts/{postId}.likes_count を-1
    //      - ローカルのposts配列とlikedPostIdsを更新
    //   2. 含まれない → いいね追加
    //      - likes/{uid}_{postId} を作成
    //      - posts/{postId}.likes_count を+1
    //      - ローカルのposts配列とlikedPostIdsを更新
    // 呼び出し元: PostCardView（ハートボタンタップ時）
    // 備考: try?でエラーを無視しているため、ネットワーク不通時でもUIは即時反映される。
    // =============================================================================
    func toggleLike(post: Post) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return }

        let likeRef = db.collection("likes").document("\(uid)_\(postId)")
        let postRef = db.collection("posts").document(postId)

        if likedPostIds.contains(postId) {
            // 楽観的UI更新（即時反映）- postsとsearchResultsの両方を更新
            likedPostIds.remove(postId)
            updateLocalLikesCount(postId: postId, delta: -1)
            // バックグラウンドでFirestore更新、エラー時は復元
            do {
                try await likeRef.delete()
                try await postRef.updateData(["likes_count": FieldValue.increment(Int64(-1))])
            } catch {
                // エラー時はUIを元に戻す
                likedPostIds.insert(postId)
                updateLocalLikesCount(postId: postId, delta: 1)
                errorMessage = "いいね解除に失敗しました: \(error.localizedDescription)"
            }
        } else {
            // 楽観的UI更新（即時反映）- postsとsearchResultsの両方を更新
            likedPostIds.insert(postId)
            updateLocalLikesCount(postId: postId, delta: 1)
            // バックグラウンドでFirestore更新、エラー時は復元
            do {
                try await likeRef.setData(["user_id": uid, "post_id": postId])
                try await postRef.updateData(["likes_count": FieldValue.increment(Int64(1))])
            } catch {
                // エラー時はUIを元に戻す
                likedPostIds.remove(postId)
                updateLocalLikesCount(postId: postId, delta: -1)
                errorMessage = "いいねに失敗しました: \(error.localizedDescription)"
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】updateLocalLikesCount
    // 目的: posts配列とsearchResults配列の両方で指定投稿のlikes_countを更新
    // 引数:
    //   - postId: 対象投稿ID
    //   - delta: 増減値 (+1 または -1)
    // =============================================================================
    private func updateLocalLikesCount(postId: String, delta: Int) {
        // posts配列を更新
        if let idx = posts.firstIndex(where: { ($0.id ?? $0.post_id) == postId }) {
            posts[idx].likes_count = max(0, posts[idx].likes_count + delta)
        }
        // searchResults配列も更新
        if let idx = searchResults.firstIndex(where: { ($0.id ?? $0.post_id) == postId }) {
            searchResults[idx].likes_count = max(0, searchResults[idx].likes_count + delta)
        }
    }

    // MARK: - Report
    // 説明: 投稿の通報（レポート）処理。一定件数で投稿が自動非表示化される。

    // =============================================================================
    // 【関数サマリー】report
    // 目的: 指定した投稿を通報し、通報カウントを増やす。5件以上で自動非表示化。
    // 引数:
    //   - post: Post - 通報対象の投稿データ
    // 戻り値: なし
    // 処理の流れ:
    //   1. 既に同じユーザーが通報済みなら何もしない（重複防止）
    //   2. reports/{uid}_{postId} に通報レコードを作成
    //   3. posts/{postId}.reports_count を+1
    //   4. reports_count >= 5 の場合 → is_hidden=true にし、タイムラインから削除
    // 呼び出し元: PostCardView（通報ボタンタップ時）
    // 備考: 通報は取り消し不可。5件という閾値は運用方針に応じて変更可能。
    // =============================================================================
    func report(post: Post) async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return }

        let reportRef = db.collection("reports").document("\(uid)_\(postId)")
        do {
            let snapshot = try await reportRef.getDocument()
            guard !snapshot.exists else {
                errorMessage = "すでに通報済みです"
                return
            }

            let postRef = db.collection("posts").document(postId)
            try await reportRef.setData(["user_id": uid, "post_id": postId])
            try await postRef.updateData(["reports_count": FieldValue.increment(Int64(1))])

            // 通報後のカウント確認と非表示化
            let postSnap = try await postRef.getDocument()
            if let count = postSnap.data()?["reports_count"] as? Int, count >= 5 {
                try await postRef.updateData(["is_hidden": true])
                await MainActor.run {
                    posts.removeAll { $0.id == postId }
                }
            }
        } catch {
            errorMessage = "通報に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - Upload Post
    // 説明: 新規投稿作成（画像アップロード＋Firestore保存）処理

    // =============================================================================
    // 【関数サマリー】uploadPost
    // 目的: ユーザーが入力した投稿内容をFirebase StorageとFirestoreに保存する
    // 引数:
    //   - frontImage: UIImage? - 正面写真（nil可）
    //   - backImage: UIImage? - 背面写真（nil可）
    //   - description: String - 投稿の説明文
    //   - regionCode: String - 都道府県コード
    //   - genderId: Int - 子供の性別ID
    //   - weatherType: String - 天気種別文字列
    //   - tempMax: Double - 最高気温
    //   - tempMin: Double - 最低気温
    //   - items: [PostItem] - 投稿に紐づく洋服アイテムリスト
    //   - user: AppUser - 投稿者のユーザーデータ（年齢計算に使用）
    // 戻り値: Bool - true=保存成功、false=失敗
    // 処理の流れ:
    //   1. 写真が1枚も選択されていない場合はエラー
    //   2. 画像をリサイズ（1200px制限）→ EXIF除去 → JPEG圧縮
    //   3. Firebase StorageにアップロードしダウンロードURLを取得
    //   4. Post構造体を作成（temp_category自動計算）
    //   5. Firestore posts/{postId} に保存
    //   6. サブコレクション items/{itemId} に各アイテムを保存
    //   7. item_tagsがあれば更新
    // 呼び出し元: NewPostView.submitPost()
    // =============================================================================
    func uploadPost(
        frontImage: UIImage?,
        backImage: UIImage?,
        description: String,
        regionCode: String,
        genderId: Int,
        weatherType: String,
        tempMax: Double,
        tempMin: Double,
        items: [PostItem],
        user: AppUser,
        isPublic: Bool = true,
        isCalendarPost: Bool = false
    ) async -> Bool {
        print("[DEBUG] uploadPost: isCalendarPost=\(isCalendarPost)")
        let itemTags = pendingItemTags
        pendingItemTags = []
        guard frontImage != nil || backImage != nil else {
            errorMessage = "フロントまたはバックの写真を1枚以上選択してください。"
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let postId = UUID().uuidString
            let ageMonths = Calendar.current.dateComponents([.month], from: user.child_birthday, to: Date()).month ?? 0
            let tempCat = tempCategoryKey(max: tempMax, min: tempMin)
            let uid = FirebaseAuth.Auth.auth().currentUser?.uid ?? user.user_id

            var frontURL: String? = nil
            var backURL: String? = nil

            if let front = frontImage, let data = stripEXIF(from: front) {
                let ref = storage.reference().child("posts/\(postId)/front.jpg")
                _ = try await ref.putDataAsync(data)
                frontURL = try await ref.downloadURL().absoluteString
            }

            if let back = backImage, let data = stripEXIF(from: back) {
                let ref = storage.reference().child("posts/\(postId)/back.jpg")
                _ = try await ref.putDataAsync(data)
                backURL = try await ref.downloadURL().absoluteString
            }

            let post = Post(
                post_id: postId,
                user_id: uid,
                image_url_front: frontURL,
                image_url_back: backURL,
                child_age_months: ageMonths,
                region_code: regionCode,
                gender_id: genderId,
                description: description,
                weather_type: weatherType,
                temp_max: tempMax,
                temp_min: tempMin,
                temp_category: tempCat,
                likes_count: 0,
                reports_count: 0,
                is_hidden: !isPublic,
                is_calendar_post: isCalendarPost,
                created_at: Timestamp(date: Date()),
                item_tags: nil,
                posterAvatarId: nil,
                posterAvatarBgColor: nil,
                posterDisplayName: nil,
                posterChildAgeName: nil
            )

            let postRef = db.collection("posts").document(postId)
            try postRef.setData(from: post)
            print("[DEBUG] Post created: post_id=\(postId), is_calendar_post=\(String(describing: post.is_calendar_post))")

            for item in items {
                let itemRef = postRef.collection("items").document(item.item_id)
                try itemRef.setData(from: item)
            }

            if !itemTags.isEmpty {
                let tagData = itemTags.map { tag -> [String: Any] in
                    return [
                        "id": tag.id,
                        "item_index": tag.item_index,
                        "x_ratio": tag.x_ratio,
                        "y_ratio": tag.y_ratio,
                        "image_side": tag.image_side
                    ]
                }
                try? await postRef.updateData(["item_tags": tagData])
            }

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers
    // 説明: 投稿作成時に使用される画像加工・計算系ユーティリティ

    // =============================================================================
    // 【関数サマリー】tempCategoryKey
    // 目的: 最高気温と最低気温から、検索用の気温帯キーを計算する
    // 引数:
    //   - max: Double - 最高気温
    //   - min: Double - 最低気温
    // 戻り値: String - 気温帯キー（"0-9"/"10-14"/"15-19"/"20-24"/"25-"）
    // 計算方法: 平均気温 = (max + min) / 2 をtempCategoriesの区間に照合
    // 呼び出し元: uploadPost()
    // =============================================================================
    private func tempCategoryKey(max: Double, min: Double) -> String {
        let avg = (max + min) / 2
        switch avg {
        case ..<10:  return "0-9"
        case 10..<15: return "10-14"
        case 15..<20: return "15-19"
        case 20..<25: return "20-24"
        default:     return "25-"
        }
    }

    // =============================================================================
    // 【関数サマリー】resizeImage
    // 目的: オリジナル画像が大きすぎる場合、長辺を指定ピクセル以下に縮小する
    // 引数:
    //   - image: UIImage - オリジナルの画像
    //   - maxDimension: CGFloat - 長辺の最大ピクセル数（デフォルト1200px）
    // 戻り値: UIImage - リサイズ後の画像（縮小不要なら元画像のまま）
    // 呼び出し元: uploadPost()
    // 備考: 大きな画像をそのままアップロードすると通信コストとStorage容量が増大する。
    // =============================================================================
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat = 1200) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        guard scale < 1.0 else { return image }
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // =============================================================================
    // 【関数サマリー】stripEXIF
    // 目的: 画像からGPS情報・撮影機器情報などのEXIFメタデータを除去する
    // 引数:
    //   - image: UIImage - 加工元の画像
    // 戻り値: Data? - EXIF除去後のJPEGバイナリデータ（失敗時はnil）
    // 処理の流れ:
    //   1. UIImageをJPEGデータに変換（品質85%）
    //   2. CGImageSourceで画像ソースを作成
    //   3. CGImageDestinationでメタデータを空の辞書に置き換えて再エンコード
    // 呼び出し元: uploadPost()
    // 備考: プライバシー保護のため、撮影位置情報などは必ず除去してからアップロードする。
    // =============================================================================
    private func stripEXIF(from image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return data }
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else { return data }
        let removeMetadata: [String: Any] = [kCGImageDestinationMetadata as String: [:]]
        CGImageDestinationAddImageFromSource(dest, source, 0, removeMetadata as CFDictionary)
        CGImageDestinationFinalize(dest)
        return mutableData as Data
    }

    // MARK: - Delete Post
    // 説明: 自分の投稿を完全に削除する処理

    // =============================================================================
    // 【関数サマリー】deletePost
    // 目的: 指定した投稿と関連する画像・いいね・サブコレクションをすべて削除する
    // 引数:
    //   - post: Post - 削除対象の投稿データ
    // 戻り値: Bool - true=削除成功、false=失敗
    // 処理の流れ:
    //   1. Firebase Storageからfront.jpgとback.jpgを削除
    //   2. Firestoreのサブコレクション items/{itemId} をすべて削除
    //   3. Firestoreのposts/{postId}ドキュメントを削除
    //   4. ローカルのposts配列とlikedPostIdsからも該当投稿を削除
    // 呼び出し元: PostDetailView（ゴミ箱ボタン→削除確認後）
    // =============================================================================
    func deletePost(_ post: Post) async -> Bool {
        let postId = post.id ?? post.post_id
        isLoading = true
        defer { isLoading = false }

        do {
            // Delete images from Storage if exist
            let storageRef = storage.reference()
            let frontRef = storageRef.child("posts/\(postId)/front.jpg")
            let backRef = storageRef.child("posts/\(postId)/back.jpg")
            // Storage画像削除は失敗しても続行（既に削除済みの場合等）
            do { try await frontRef.delete() } catch { print("Front image delete failed or already deleted: \(error)") }
            do { try await backRef.delete() } catch { print("Back image delete failed or already deleted: \(error)") }

            // Delete subcollection items
            let postRef = db.collection("posts").document(postId)
            let itemsSnap = try await postRef.collection("items").getDocuments()
            for doc in itemsSnap.documents {
                try await doc.reference.delete()
            }

            // Delete the post document
            try await postRef.delete()

            // Update local state on main actor
            await MainActor.run {
                posts.removeAll { $0.id == postId }
                likedPostIds.remove(postId)
            }
            return true
        } catch {
            errorMessage = "投稿削除に失敗しました: \(error.localizedDescription)"
            return false
        }
    }
}

// =============================================================================
// MARK: - DraftManager
// 役割: 新規投稿の下書きをローカル（UserDefaults＋Documentsフォルダ）で管理する
// 説明:
//   投稿作成中にアプリが閉じられたり、他の画面に移動しても、入力内容と画像を
//   保持しておくためのクラスです。下書きは最大20件まで保存されます。
//   画像はアプリのDocumentsフォルダにファイルとして保存され、下書きデータには
//   そのファイル名（パス）のみがJSONとしてUserDefaultsに保存されます。
// =============================================================================

class DraftManager: ObservableObject {
    // 現在選択中・編集対象になっている下書き。NewPostViewがこれを監視して
    // 自動的にシート表示を行う。
    @Published var pendingDraft: PostDraft? = nil

    // UserDefaultsに保存する下書きリストのキー
    private let draftsKey = "savedDraftsList_v2"

    // 計算プロパティ: UserDefaultsから下書きリストを読み込む
    var drafts: [PostDraft] {
        guard let data = UserDefaults.standard.data(forKey: draftsKey),
              let list = try? JSONDecoder().decode([PostDraft].self, from: data) else { return [] }
        return list
    }

    // =============================================================================
    // 【関数サマリー】saveDraft
    // 目的: 下書きを保存する。同じIDがあれば上書き、なければリスト先頭に追加
    // 引数:
    //   - draft: PostDraft - 保存する下書きデータ
    // 戻り値: なし
    // 処理の流れ:
    //   1. 同じIDの下書きがあれば置き換え、なければ先頭に追加
    //   2. 20件を超える場合は古いものを切り捨て
    //   3. JSONエンコードしてUserDefaultsに保存
    // 呼び出し元: NewPostView.saveDraft()
    // =============================================================================
    func saveDraft(_ draft: PostDraft) {
        var current = drafts
        if let idx = current.firstIndex(where: { $0.id == draft.id }) {
            current[idx] = draft
        } else {
            current.insert(draft, at: 0)
        }
        if current.count > 20 { current = Array(current.prefix(20)) }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: draftsKey)
        }
    }

    // =============================================================================
    // 【関数サマリー】deleteDraft
    // 目的: 指定したインデックスの下書きを削除し、関連する画像ファイルも破棄する
    // 引数:
    //   - offsets: IndexSet - 削除対象のインデックス集合（SwiftUIの.onDeleteから渡される）
    // 戻り値: なし
    // 処理の流れ:
    //   1. 削除対象の下書きに紐づく画像ファイルパスを取得
    //   2. Documentsフォルダから各画像ファイルを物理削除
    //   3. 下書きリストから該当インデックスを削除
    //   4. 更新後のリストをUserDefaultsに保存
    // 呼び出し元: DraftListView.onDelete（スワイプ削除時）
    // =============================================================================
    func deleteDraft(at offsets: IndexSet) {
        var current = drafts
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for idx in offsets where idx < current.count {
            let draft = current[idx]
            if let path = draft.frontImagePath {
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
            }
            if let path = draft.backImagePath {
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
            }
        }
        current.remove(atOffsets: offsets)
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: draftsKey)
        }
    }

    // =============================================================================
    // 【関数サマリー】selectDraft
    // 目的: 指定した下書きを選択状態（pendingDraft）に設定する
    // 引数:
    //   - draft: PostDraft - 選択する下書きデータ
    // 戻り値: なし
    // 処理の流れ:
    //   1. pendingDraftにセット
    //   2. MainTabViewがpendingDraftの変更を検知し、自動でNewPostViewシートを表示
    // 呼び出し元: DraftListView（下書き行タップ時）
    // =============================================================================
    func selectDraft(_ draft: PostDraft) {
        pendingDraft = draft
    }

    // =============================================================================
    // 【関数サマリー】clearPendingDraft
    // 目的: 選択中の下書きをクリアする
    // 引数: なし
    // 戻り値: なし
    // 呼び出し元: NewPostView（下書き適用後やシート閉じる際）
    // =============================================================================
    func clearPendingDraft() {
        pendingDraft = nil
    }

    // =============================================================================
    // 【関数サマリー】cleanupDraftImages
    // 目的: 指定した下書きIDに紐づく画像ファイルのみを削除する（下書きデータ自体は残す）
    // 引数:
    //   - draftId: String - 画像を削除する下書きのID
    // 戻り値: なし
    // 処理の流れ:
    //   1. 下書きリストから該当IDの下書きを検索
    //   2. frontImagePath / backImagePath に対応する画像ファイルを削除
    //   3. 下書きデータ自体は削除しない（呼び出し側で別途削除する）
    // 呼び出し元: NewPostView（投稿成功後に下書き画像をクリーンアップ）
    // =============================================================================
    func cleanupDraftImages(draftId: String) {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let draft = drafts.first(where: { $0.id == draftId }) {
            if let path = draft.frontImagePath {
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
                print("Cleaned up draft front image: \(path)")
            }
            if let path = draft.backImagePath {
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
                print("Cleaned up draft back image: \(path)")
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】deleteDraftById
    // 目的: 指定したIDの下書きを削除し、関連する画像ファイルも破棄する
    // 引数:
    //   - draftId: String - 削除する下書きのID
    // 戻り値: Bool - true=削除成功、false=該当下書きなし
    // 呼び出し元: NewPostView（投稿成功後に下書きを完全削除）
    // =============================================================================
    @discardableResult
    func deleteDraftById(_ draftId: String) -> Bool {
        var current = drafts
        guard let idx = current.firstIndex(where: { $0.id == draftId }) else { return false }

        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let draft = current[idx]
        if let path = draft.frontImagePath {
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
        }
        if let path = draft.backImagePath {
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(path))
        }

        current.remove(at: idx)
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: draftsKey)
        }
        print("Deleted draft with images: \(draftId)")
        return true
    }
}

