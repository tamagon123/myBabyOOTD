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
    @State private var selectedTab: Int = 0                    // 選択中のタブ（0=ホーム,1=検索,2=マイページ）
    @State private var showNewPost = false                     // 新規投稿シートの表示状態
    @State private var profileRefreshId = UUID()               // プロフィールViewの強制再描画用ID

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
                    SearchView()
                        .environmentObject(authViewModel)
                case 2:
                    ProfileView(userId: Auth.currentUID)
                        .environmentObject(authViewModel)
                        .environmentObject(postsViewModel)
                        .environmentObject(draftManager)
                        .id(profileRefreshId)  // このIDを変えるとViewが再構築されリフレッシュされる
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
        // 画面表示時にプッシュ通知の許可を要求・FCMトークンを保存
        .onAppear {
            NotificationService.shared.requestPermissionIfNeeded()
            NotificationService.shared.saveFCMTokenIfSignedIn()
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
    var onPostTap: () -> Void       // +ボタンタップ時のコールバック

    var body: some View {
        HStack {
            // 左: ホームボタン（タブ0）
            navItem(icon: "house.fill",   label: "ホーム",  tab: 0)
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
            .offset(y: -12)  // ナビバーから少し上に浮かせる
            Spacer()
            // 右: マイページボタン（タブ2）
            navItem(icon: "person.fill",  label: "マイページ", tab: 2)
        }
        .padding(.horizontal, 32)
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

