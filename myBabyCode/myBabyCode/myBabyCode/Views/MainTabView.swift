// =============================================================================
// ファイル名: MainTabView.swift
// 役割: アプリのメイン画面構成（タブ切り替え＋新規投稿シート＋下部ナビゲーション）
// 説明:
//   ログイン後のメイン画面を構成するViewです。3つのタブ（ホーム・検索・マイページ）を
//   ZStackで切り替え、下部にカスタムナビゲーションバーと広告バナー領域を配置します。
//   中央の+ボタンで新規投稿シート（NewPostView）を表示します。
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

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: メイン画面の全体レイアウト（コンテンツ + 広告 + ナビ + シート）を定義
    // 構成:
    //   1. ZStackでタブに応じた画面切り替え（HomeView / SearchView / ProfileView）
    //   2. AdBannerView（広告バナー領域・現在はプレースホルダー）
    //   3. BottomNavBar（カスタム下部ナビゲーション、中央に投稿ボタン）
    //   4. .sheetでNewPostViewをモーダル表示
    // 備考: .id(profileRefreshId)により、投稿シートを閉じた時にProfileViewを強制リフレッシュする。
    // =============================================================================
    var body: some View {
        VStack(spacing: 0) {
            // タブに応じたメインコンテンツ領域
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

            // 広告バナー表示領域（現在はプレースホルダー）
            AdBannerView()

            // 下部カスタムナビゲーションバー
            BottomNavBar(
                selectedTab: $selectedTab,
                unreadCount: unreadCount,
                onPostTap: { showNewPost = true }
            )
        }
        .ignoresSafeArea(edges: .bottom)
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
        // プッシュ通知タップ時に対応するタブへ遷移
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NotificationTapped"))) { notification in
            guard let userInfo = notification.userInfo,
                  let type = userInfo["type"] as? String else { return }

            print("[MainTabView] Notification tapped: type=\(type)")

            switch type {
            case "new_post", "like":
                selectedTab = 0  // ホーム
            case "follow":
                selectedTab = 3  // マイページ
            case "diary_reminder":
                selectedTab = 1  // カレンダー
            default:
                break
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
                        .font(.system(size: 24, weight: .bold))
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
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10))
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
                        .font(.system(size: 22))
                    Text(label)
                        .font(.system(size: 10))
                }
                .foregroundColor(selectedTab == tab ? .accentRed : Color(.systemGray3))

                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
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

