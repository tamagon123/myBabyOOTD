// =============================================================================
// ファイル名: MainTabView.swift
// 役割: アプリのメイン画面構成（タブ切り替え＋新規投稿シート＋下部ナビゲーション）
// 説明:
//   ログイン後のメイン画面を構成するViewです。4つのタブ（ホーム・カレンダー・買い物・マイページ）を
//   ZStackで切り替え、下部にカスタムナビゲーションバーと広告バナー領域を配置します。
//   中央の+ボタンで新規投稿シート（NewPostView）を表示します。
//   iPad対応: 常時固定サイドバー（80px幅・濃い生成り色背景）+ コンテンツエリアの2ペイン構成。
//   また、ViewModel（PostsViewModel, DraftManager）を生成・保持し、
//   各子ViewにenvironmentObjectとして配布します。
// =============================================================================

import SwiftUI
import FirebaseAuth
import Combine

struct MainTabView: View {
    // === 環境・状態 ===
    @EnvironmentObject var authViewModel: AuthViewModel        // 認証状態（親から受け取る）
    @StateObject private var postsViewModel = PostsViewModel() // 投稿管理（自身で生成・保持）
    @StateObject private var draftManager = DraftManager()       // 下書き管理（自身で生成・保持）
    @State private var selectedTab: Int = 0                    // 選択中のタブ（0=ホーム,1=カレンダー,2=買い物,3=マイページ）
    @StateObject private var calendarViewModel = CalendarViewModel()
    @State private var showNewPost = false                     // 新規投稿シートの表示状態
    @State private var profileRefreshId = UUID()               // プロフィールViewの強制再描画用ID
    @State private var unreadCount: Int = 0                    // 未読通知数
    
    // === 通知タップによる詳細画面表示用 ===
    @State private var showPostDetail = false                  // 投稿詳細画面表示
    @State private var targetPostId: String? = nil            // 表示対象の投稿ID
    @State private var showProfile = false                      // プロフィール画面表示
    @State private var targetUserId: String? = nil             // 表示対象のユーザーID

    @StateObject private var updateChecker = AppUpdateChecker.shared
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: メイン画面の全体レイアウト（コンテンツ + 広告 + ナビ + シート）を定義
    // 構成:
    //   iPhone: ZStack切り替え + BottomNavBar
    //   iPad:   NavigationSplitView でサイドバー + コンテンツ
    // =============================================================================
    var body: some View {
        Group {
            if isIPad {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        // 新規投稿画面（+ボタンまたは下書き選択時にフルスクリーン表示）
        .fullScreenCover(isPresented: $showNewPost, onDismiss: {
            // 閉じたらプロフィールViewを再描画（投稿件数更新のため）
            profileRefreshId = UUID()
        }) {
            NewPostView()
                .environmentObject(postsViewModel)
                .environmentObject(authViewModel)
                .environmentObject(draftManager)
        }
        // 下書きが選択されたら自動的に投稿シートを表示
        .onChange(of: draftManager.pendingDraft != nil) { hasDraft in
            if hasDraft {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showNewPost = true
                }
            }
        }
        // 画面表示時にプッシュ通知の許可を要求・FCMトークンを保存・未読数を取得
        // ブランド・アフィリエイト情報もFirestoreから取得
        .onAppear {
            NotificationService.shared.requestPermissionIfNeeded()
            NotificationService.shared.saveFCMTokenIfSignedIn()
            refreshUnreadCount()
            UIApplication.shared.applicationIconBadgeNumber = 0
            Task {
                await BrandService.shared.fetchAll()
            }
        }
        // マイページタブ選択時に未読数を更新
        .onChange(of: selectedTab) { tab in
            if tab == 3 {
                refreshUnreadCount()
            }
        }
        // プッシュ通知タップ時に対応する画面へ遷移
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotificationTapped"))) { notification in
            guard let userInfo = notification.userInfo,
                  let type = userInfo["type"] as? String else { return }

            print("[MainTabView] Notification tapped: type=\(type)")

            switch type {
            case "new_post":
                // フォロー中のアカウントの新規投稿 → 該当投稿の詳細画面へ
                if let postId = userInfo["post_id"] as? String {
                    targetPostId = postId
                    showPostDetail = true
                } else {
                    selectedTab = 0  // 投稿IDがない場合はホームへ
                }
            case "like":
                // いいね通知 → 該当投稿の詳細画面へ
                if let postId = userInfo["post_id"] as? String {
                    targetPostId = postId
                    showPostDetail = true
                } else {
                    selectedTab = 0  // 投稿IDがない場合はホームへ
                }
            case "follow":
                // フォローされた通知 → フォローした相手のプロフィールへ
                if let followerId = userInfo["follower_id"] as? String {
                    targetUserId = followerId
                    showProfile = true
                } else {
                    selectedTab = 3  // フォロワーIDがない場合はマイページへ
                }
            case "diary_reminder":
                selectedTab = 1  // カレンダー
            default:
                break
            }
        }
        // 投稿詳細画面（通知タップ時）
        .sheet(isPresented: $showPostDetail) {
            if let postId = targetPostId {
                NavigationView {
                    PostDetailView(post: nil, postId: postId)
                        .environmentObject(authViewModel)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        // プロフィール画面（通知タップ時：フォローされた相手）
        .sheet(isPresented: $showProfile) {
            if let userId = targetUserId {
                NavigationView {
                    ProfileView(userId: userId)
                        .environmentObject(authViewModel)
                        .environmentObject(postsViewModel)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        // 任意のタブへの遷移（カレンダーなどからの検索結果表示用）
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToTab"))) { notification in
            guard let userInfo = notification.userInfo,
                  let tab = userInfo["tab"] as? Int else { return }
            selectedTab = tab
        }
        // 通知全削除後にバッジを更新
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotificationsDeleted"))) { _ in
            refreshUnreadCount()
        }
        // アップデート通知アラート（新バージョンがある間は毎回起動時に表示）
        .alert("アップデートのお知らせ", isPresented: $updateChecker.isUpdateAvailable) {
            Button("今すぐ更新") {
                updateChecker.openAppStore()
            }
            Button("後で", role: .cancel) {}
        } message: {
            Text("新しいバージョン（\(updateChecker.latestVersion)）が公開されました。\nアップデートすると最新の機能や修正をご利用いただけます。")
        }
    }

    // MARK: - iPhone Layout（従来のBottomNavBar構成）
    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selectedTab {
                case 0:
                    HomeView()
                        .environmentObject(postsViewModel)
                        .environmentObject(authViewModel)
                case 1:
                    CalendarView()
                        .environmentObject(authViewModel)
                        .environmentObject(calendarViewModel)
                        .environmentObject(postsViewModel)
                case 2:
                    ShoppingView()
                        .environmentObject(authViewModel)
                case 3:
                    ProfileView(userId: Auth.currentUID)
                        .environmentObject(authViewModel)
                        .environmentObject(postsViewModel)
                        .environmentObject(draftManager)
                        .id(profileRefreshId)
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AdBannerView()

            BottomNavBar(
                selectedTab: $selectedTab,
                unreadCount: unreadCount,
                onPostTap: { showNewPost = true }
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - iPad Layout（常時固定サイドバー + コンテンツ）
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            iPadSidebar
                .frame(width: 80)
            Divider()
            iPadDetailContent
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var iPadSidebar: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            iPadNavIconItem(icon: "house.fill",   tab: 0)
            iPadNavIconItem(icon: "calendar",     tab: 1)
            iPadNavIconItem(icon: "bag.fill",     tab: 2)
            iPadNavIconItemWithBadge(icon: "person.fill", tab: 3, badge: unreadCount)
            Divider().padding(.horizontal, 12)
            Button(action: { showNewPost = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.accentRed)
                    .clipShape(Circle())
                    .shadow(color: Color.accentRed.opacity(0.3), radius: 8, y: 4)
            }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .background(
            Color(red: 0.91, green: 0.87, blue: 0.77)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var iPadDetailContent: some View {
        VStack(spacing: 0) {
            NavigationView {
                ZStack {
                    switch selectedTab {
                    case 0:
                        HomeView()
                            .environmentObject(postsViewModel)
                            .environmentObject(authViewModel)
                    case 1:
                        CalendarView()
                            .environmentObject(authViewModel)
                            .environmentObject(calendarViewModel)
                            .environmentObject(postsViewModel)
                    case 2:
                        ShoppingView()
                            .environmentObject(authViewModel)
                    case 3:
                        ProfileView(userId: Auth.currentUID)
                            .environmentObject(authViewModel)
                            .environmentObject(postsViewModel)
                            .environmentObject(draftManager)
                            .id(profileRefreshId)
                    default:
                        EmptyView()
                    }
                }
                .navigationBarHidden(true)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AdBannerView()
        }
    }

    @ViewBuilder
    private func iPadNavIconItem(icon: String, tab: Int) -> some View {
        Button { selectedTab = tab } label: {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(selectedTab == tab ? .accentRed : Color(.secondaryLabel))
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedTab == tab ? Color.accentRed.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func iPadNavIconItemWithBadge(icon: String, tab: Int, badge: Int) -> some View {
        Button { selectedTab = tab } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedTab == tab ? .accentRed : Color(.secondaryLabel))
                    .frame(width: 52, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTab == tab ? Color.accentRed.opacity(0.1) : Color.clear)
                    )
                if badge > 0 {
                    Text("\(badge)")
                        .font(.appFont(.regular, size: 9))
                        .foregroundColor(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .background(Color.accentRed)
                        .clipShape(Capsule())
                        .offset(x: 6, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func refreshUnreadCount() {
        let uid = Auth.currentUID
        guard !uid.isEmpty else { return }
        Task {
            let count = await NotificationService.shared.fetchUnreadCount(uid: uid)
            await MainActor.run {
                unreadCount = count
            }
        }
    }
}

// =============================================================================
// MARK: - BottomNavBar
// 役割: カスタム下部ナビゲーションバー
// 説明:
//   標準のTabViewではなく、HStackで自作したナビゲーションバーです。
//   中央に浮き出た赤い+ボタン（新規投稿）を持ち、左右にホームとマイページの
//   アイコン＋ラベルを配置しています。タブ選択時は朱色に、未選択時はグレーに変化します。
// =============================================================================

struct BottomNavBar: View {
    @Binding var selectedTab: Int   // 双方向バインディング: MainTabViewとタブ状態を同期
    var unreadCount: Int = 0        // 未読通知数（マイページタブのバッジ用）
    var onPostTap: () -> Void       // +ボタンタップ時のコールバック

    var body: some View {
        HStack {
            // ホームボタン（タブ0）
            navItem(icon: "house.fill",   label: "ホーム",  tab: 0)
            Spacer()
            // カレンダーボタン（タブ1）
            navItem(icon: "calendar", label: "カレンダー", tab: 1)
            Spacer()
            // 中央: 新規投稿ボタン（赤い浮き出し円）
            Button(action: onPostTap) {
                ZStack {
                    Circle()
                        .fill(Color.accentRed)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.accentRed.opacity(0.3), radius: 8, y: 4)
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.appFont(.bold, size: 24))
                }
            }
            .offset(y: -12)
            Spacer()
            // 買い物ボタン（タブ2）
            navItem(icon: "bag.fill", label: "買い物", tab: 2)
            Spacer()
            // マイページボタン（タブ3）
            navItemWithBadge(icon: "person.fill", label: "マイページ", tab: 3, badge: unreadCount)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
        )
    }

    // =============================================================================
    // 【Viewサマリー】navItem
    // 目的: 個別のナビゲーションアイテム（アイコン＋ラベル）を生成する
    // 引数:
    //   - icon: String - SF Symbolsのアイコン名
    //   - label: String - ボタン下に表示する日本語ラベル
    //   - tab: Int - このボタンが対応するタブ番号
    // 戻り値: some View（ボタンView）
    // =============================================================================
    @ViewBuilder
    private func navItem(icon: String, label: String, tab: Int) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.appFont(.regular, size: 22))
                Text(label)
                    .font(.appFont(.regular, size: 10))
            }
            // 選択中のタブは朱色、未選択はグレー
            .foregroundColor(selectedTab == tab ? .accentRed : Color(.systemGray3))
        }
    }

    @ViewBuilder
    private func navItemWithBadge(icon: String, label: String, tab: Int, badge: Int) -> some View {
        Button {
            selectedTab = tab
        } label: {
            ZStack {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.appFont(.bold, size: 22))
                    Text(label)
                        .font(.appFont(.regular, size: 10))
                }
                .foregroundColor(selectedTab == tab ? .accentRed : Color(.systemGray3))

                if badge > 0 {
                    Text("\(badge)")
                        .font(.appFont(.regular, size: 10))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.accentRed)
                        .clipShape(Capsule())
                        .offset(x: 14, y: -10)
                }
            }
        }
    }
}

// =============================================================================
// MARK: - Auth helper shim
// 役割: Firebase Authの現在のUIDを安全に取得するヘルパー
// 説明: FirebaseAuth.Auth.auth().currentUser?.uid のラッパー。未ログイン時は空文字を返す。
// =============================================================================

enum Auth {
    static var currentUID: String {
        FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
    }
}

