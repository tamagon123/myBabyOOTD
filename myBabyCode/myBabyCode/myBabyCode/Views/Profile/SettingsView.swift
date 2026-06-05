// =============================================================================
// ファイル名: SettingsView.swift
// 役割: 設定画面（プロフィール編集・下書き一覧・規約・ログアウト・アカウント削除）
// 説明:
//   マイページの歯車アイコンから遷移する設定画面です。
//   List形式で各種設定項目を表示し、プロフィール編集、下書き一覧、利用規約・
//   プライバシーポリシー閲覧、ログアウト、アカウント削除の各機能へ導きます。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import AuthenticationServices

struct SettingsView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel  // 認証・ユーザー情報
    @EnvironmentObject var draftManager: DraftManager    // 下書き管理
    @Environment(\.dismiss) private var dismiss            // 画面を閉じる

    // === サブスクリプション ===
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    // === アラート表示フラグ ===
    @State private var showSignOutAlert = false       // ログアウト確認アラート
    @State private var showDeleteAccountAlert = false  // アカウント削除確認アラート
    @State private var showReauthAlert = false        // 再認証（パスワード入力）アラート
    @State private var reauthPassword = ""           // 再認証用パスワード入力
    @State private var showAppleReauthSheet = false  // Apple Sign In再認証シート
    @State private var showUnsubscribeAlert = false   // プレミアム解除確認アラート
    @State private var reminderEnabled: Bool = false  // 日記リマインダー ON/OFF
    @State private var reminderTime: Date = {         // 日記リマインダー時刻
        var cal = Calendar.current
        var comps = DateComponents()
        comps.hour = 21
        comps.minute = 0
        return cal.date(from: comps) ?? Date()
    }()

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 設定画面の全体レイアウトを定義
    // 構成:
    //   1. Listでセクション分けして表示
    //   2. 「アカウント」セクション: プロフィール編集へのリンク
    //   3. 「投稿」セクション: 下書き一覧（件数バッジ付き）
    //   4. 「法的情報」セクション: 利用規約・プライバシーポリシー
    //   5. 「その他」セクション: ログアウト・アカウント削除
    // =============================================================================
    var body: some View {
        NavigationView {
            List {
                // --- アカウントセクション ---
                Section {
                    NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
                        Label("プロフィールを編集", systemImage: "person.crop.circle")
                    }
                    NavigationLink(destination: BlockListView()) {
                        Label("ブロックリスト", systemImage: "hand.raised")
                    }
                } header: {
                    Text("アカウント")
                }

                // --- 投稿セクション ---
                Section {
                    // 投稿公開設定（カレンダーのみ公開は不可）
                    PostPublicToggle()
                    
                    NavigationLink(destination: DraftListView(onDraftSelected: { dismiss() })
                        .environmentObject(draftManager)) {
                        HStack {
                            Label("下書き一覧", systemImage: "doc.text")
                            Spacer()
                            let count = draftManager.drafts.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.appFont(.medium, size: 12))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentGreen)
                                    .cornerRadius(10)
                            }
                        }
                    }
                } header: {
                    Text("投稿")
                }

                // --- カレンダー設定セクション ---
                Section {
                    CalendarPublicToggle()
                    Toggle(isOn: $reminderEnabled) {
                        Label("日記リマインダー", systemImage: "bell.badge")
                    }
                    .onChange(of: reminderEnabled) { enabled in
                        saveReminderSettings(enabled: enabled, time: reminderTime)
                    }
                    if reminderEnabled {
                        DatePicker(
                            "通知時刻",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .onChange(of: reminderTime) { time in
                            saveReminderSettings(enabled: reminderEnabled, time: time)
                        }
                    }
                } header: {
                    Text("カレンダー")
                } footer: {
                    Text("カレンダーを公開すると日記がタイムラインに表示されます。カレンダーのみ公開はできません。日記リマインダーをオンにすると、その日に日記を書いていない場合にお知らせします。")
                }

                // --- アプリについてセクション ---
                Section {
                    NavigationLink(destination: AppGuideView()) {
                        Label("アプリの使い方", systemImage: "book.fill")
                    }
                } header: {
                    Text("アプリについて")
                }

                // --- プレミアム・広告設定セクション ---
                Section {
                    if subscriptionManager.isSubscribed {
                        HStack {
                            Label("広告非表示中", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.accentGreen)
                            Spacer()
                            Text("プレミアム")
                                .font(.appFont(.medium, size: 12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentGreen)
                                .cornerRadius(10)
                        }

                        Button(role: .destructive) {
                            showUnsubscribeAlert = true
                        } label: {
                            Label("プレミアムを解除", systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            Task { await subscriptionManager.purchase() }
                        } label: {
                            HStack {
                                Label("広告を非表示にする", systemImage: "star.fill")
                                    .foregroundColor(.primary)
                                Spacer()
                                if subscriptionManager.isPurchasing {
                                    ProgressView().scaleEffect(0.8)
                                } else if let price = subscriptionManager.productPrice {
                                    Text(price)
                                        .font(.appFont(.medium, size: 13))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor)
                                        .cornerRadius(10)
                                } else {
                                    Text("購入")
                                        .font(.appFont(.medium, size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .disabled(subscriptionManager.isPurchasing)

                        Button {
                            Task { await subscriptionManager.restorePurchases() }
                        } label: {
                            Label("購入を復元する", systemImage: "arrow.clockwise")
                                .foregroundColor(.secondary)
                        }
                        .disabled(subscriptionManager.isPurchasing)
                    }
                } header: {
                    Text("プレミアム")
                } footer: {
                    Text("買い切り型プレミアムプランです。広告非表示＋日記を１年前まで編集可能になります。購入はApp Store経由で行われます。")
                        .font(.caption)
                }

                // --- 通知設定セクション ---
                Section {
                    NavigationLink(destination: NotificationSettingsView().environmentObject(authViewModel)) {
                        Label("通知の設定", systemImage: "bell")
                    }
                } header: {
                    Text("通知")
                }

                // --- 法的情報セクション ---
                Section {
                    NavigationLink(destination: TermsOfServiceView()) {
                        Label("利用規約", systemImage: "doc.text")
                    }
                    NavigationLink(destination: PrivacyPolicyView()) {
                        Label("プライバシーポリシー", systemImage: "lock.shield")
                    }
                } header: {
                    Text("法的情報")
                }

                // --- ログアウトセクション ---
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("ログアウト")
                }

                // --- アカウント削除セクション（分離）---
                Section {
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("アカウントを削除", systemImage: "person.crop.circle.badge.minus")
                    }
                } header: {
                    Text("危険な操作")
                } footer: {
                    Text("アカウントを削除すると、投稿・フォロワー情報など全データが失われます。この操作は取り消せません。")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // バナー広告（プレミアム加入で非表示）
                AdBannerView()
            }
            .task {
                await subscriptionManager.loadProduct()
                loadReminderSettings()
            }
            .alert("エラー", isPresented: Binding(
                get: { subscriptionManager.errorMessage != nil },
                set: { if !$0 { subscriptionManager.errorMessage = nil } }
            )) {
                Button("OK") { subscriptionManager.errorMessage = nil }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
            .alert("ログアウト", isPresented: $showSignOutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
            } message: {
                Text("ログアウトしますか？")
            }
            .alert("アカウントの削除", isPresented: $showDeleteAccountAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("次へ", role: .destructive) {
                    if authViewModel.isGoogleUser {
                        // GoogleユーザーはGoogleサインインで再認証
                        Task {
                            let reauthSuccess = await authViewModel.reauthenticateWithGoogle()
                            if reauthSuccess {
                                await authViewModel.deleteAccount()
                                dismiss()
                            }
                        }
                    } else if authViewModel.isAppleUser {
                        // AppleユーザーはSign in with Appleで再認証
                        showAppleReauthSheet = true
                    } else if authViewModel.isEmailUser {
                        // Emailユーザーはパスワード入力
                        showReauthAlert = true
                    } else {
                        // その他は再ログインを促す
                        showReauthAlert = true
                    }
                }
            } message: {
                Text("アカウントを削除すると、投稿履歴やフォロワー情報など全てのデータが失われます。この操作は元に戻せません。")
            }
            .alert("パスワードを入力してください", isPresented: $showReauthAlert) {
                SecureField("パスワード", text: $reauthPassword)
                Button("キャンセル", role: .cancel) {
                    reauthPassword = ""
                }
                Button("削除する", role: .destructive) {
                    Task {
                        let reauthSuccess = await authViewModel.reauthenticate(password: reauthPassword)
                        reauthPassword = ""
                        if reauthSuccess {
                            await authViewModel.deleteAccount()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("セキュリティのため、パスワードを再度入力してください。")
            }
            .alert("プレミアムを解除", isPresented: $showUnsubscribeAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("解除する", role: .destructive) {
                    subscriptionManager.setPremium(false)
                }
            } message: {
                Text("プレミアム状態を解除すると、広告表示と日記編集制限が復活します。買い切り購入の場合、「購入を復元する」から再度有効化できます。よろしいですか？")
            }
            // Apple Sign In 再認証シート（アカウント削除前）
            .sheet(isPresented: $showAppleReauthSheet) {
                VStack(spacing: 32) {
                    Text("セキュリティのため\n再度Appleでサインインしてください")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.top, 40)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = authViewModel.prepareSignInWithApple()
                    } onCompletion: { result in
                        authViewModel.handleSignInWithApple(result: result)
                        Task {
                            let reauthSuccess = await authViewModel.reauthenticateWithApple()
                            showAppleReauthSheet = false
                            if reauthSuccess {
                                await authViewModel.deleteAccount()
                                dismiss()
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 52)
                    .cornerRadius(14)
                    .padding(.horizontal, 28)

                    Button("キャンセル") {
                        showAppleReauthSheet = false
                    }
                    .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - リマインダー設定の保存・読み込み

    private func saveReminderSettings(enabled: Bool, time: Date) {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let cal = Calendar.current
        let hour = cal.component(.hour, from: time)
        let minute = cal.component(.minute, from: time)
        Task {
            try? await Firestore.firestore().collection("users").document(uid).updateData([
                "diary_reminder_enabled": enabled,
                "diary_reminder_hour": hour,
                "diary_reminder_minute": minute
            ])
        }
    }

    private func loadReminderSettings() {
        guard let user = authViewModel.currentUser else { return }
        reminderEnabled = user.diary_reminder_enabled ?? false
        let hour = user.diary_reminder_hour ?? 21
        let minute = user.diary_reminder_minute ?? 0
        var cal = Calendar.current
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        reminderTime = cal.date(from: comps) ?? reminderTime
    }
}

// MARK: - Draft List View

struct DraftListView: View {
    @EnvironmentObject var draftManager: DraftManager
    var onDraftSelected: () -> Void

    var body: some View {
        let drafts = draftManager.drafts
        List {
            if drafts.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.appFont(.regular, size: 36))
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("下書きはありません")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(drafts.indices, id: \.self) { idx in
                    let draft = drafts[idx]
                    Button {
                        draftManager.selectDraft(draft)
                        onDraftSelected()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.description.isEmpty ? "（説明なし）" : draft.description)
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            HStack(spacing: 10) {
                                Text(formattedDate(draft.savedAt))
                                    .font(.appFont(.regular, size: 11))
                                    .foregroundColor(.secondary)
                                if !draft.items.isEmpty {
                                    Text("\(draft.items.count)アイテム")
                                        .font(.appFont(.regular, size: 11))
                                        .foregroundColor(.accentBlue)
                                }
                                let wt = WeatherType(rawValue: draft.weatherType)
                                Label("\(draft.tempMax)℃/\(draft.tempMin)℃", systemImage: wt?.sfSymbol ?? "cloud.sun")
                                    .font(.appFont(.regular, size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    draftManager.deleteDraft(at: offsets)
                }
            }
        }
        .navigationTitle("下書き一覧")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - PremiumBannerCard
// 設定画面上部に表示するサブスクリプション加入促進バナー

struct PremiumBannerCard: View {
    let isPurchasing: Bool
    let onPurchase: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // グラデーション背景ヘッダー
            ZStack {
                LinearGradient(
                    colors: [Color.accentRed, Color.accentRed.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.appFont(.bold, size: 22))
                            .foregroundColor(.yellow)
                        Text("プレミアムプラン")
                            .font(.appFont(.regular, size: 20))
                            .foregroundColor(.white)
                    }

                    Text("買い切り型プレミアムプラン\n一度購入するだけで永久利用できます")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    // 特典リスト
                    VStack(alignment: .leading, spacing: 6) {
                        PremiumFeatureRow(icon: "nosign", text: "全広告を非表示")
                        PremiumFeatureRow(icon: "calendar", text: "日記を１年前まで編集可能")
                        PremiumFeatureRow(icon: "heart.fill", text: "アプリ開発を応援できる")
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            // ボタンエリア
            VStack(spacing: 10) {
                Button(action: onPurchase) {
                    HStack(spacing: 8) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "star.fill")
                                .font(.appFont(.bold, size: 15))
                        }
                        Text(isPurchasing ? "処理中..." : "プレミアムを購入する")
                            .font(.appFont(.regular, size: 16))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isPurchasing ? Color.accentRed.opacity(0.6) : Color.accentRed)
                    .cornerRadius(12)
                }
                .disabled(isPurchasing)
                .buttonStyle(.plain)

                Button(action: onRestore) {
                    Text("購入を復元する")
                        .font(.appFont(.regular, size: 13))
                        .foregroundColor(.secondary)
                }
                .disabled(isPurchasing)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - CalendarPublicToggle
// カレンダー公開設定のToggle

struct CalendarPublicToggle: View {
    @State private var isPublic: Bool = false
    @State private var isLoading = false
    @State private var postsArePublic: Bool = true  // 投稿公開設定を監視
    private let db = Firestore.firestore()
    private var uid: String { FirebaseAuth.Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        Toggle(isOn: $isPublic) {
            HStack(spacing: 8) {
                Image(systemName: isPublic ? "globe" : "lock.fill")
                    .foregroundColor(isPublic ? .accentBlue : Color(.systemGray))
                VStack(alignment: .leading, spacing: 2) {
                    Text("カレンダーを公開する")
                        .font(.appFont(.medium, size: 15))
                    Text(isPublic ? "フォロワーがあなたのカレンダーを見られます" : "自分だけがカレンダーを見られます")
                        .font(.appFont(.medium, size: 12))
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .tint(.accentBlue)
        .onChange(of: isPublic) { newValue in
            Task { await saveSetting(isPublic: newValue) }
        }
        .task { await loadBothSettings() }
        .disabled(isLoading || !postsArePublic)  // 投稿非公開時はカレンダー公開不可
    }

    private func loadBothSettings() async {
        isLoading = true
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            isPublic = doc.data()?["calendar_is_public"] as? Bool ?? false
            postsArePublic = doc.data()?["posts_are_public"] as? Bool ?? true
        } catch {}
        isLoading = false
    }

    private func saveSetting(isPublic: Bool) async {
        isLoading = true
        // 投稿非公開の場合はカレンダー公開不可（カレンダーのみ公開は不可）
        guard postsArePublic else {
            isLoading = false
            return
        }
        try? await db.collection("users").document(uid).updateData([
            "calendar_is_public": isPublic
        ])
        isLoading = false
    }
}

// MARK: - PremiumFeatureRow
// プレミアムバナー内の特典1行表示

private struct PremiumFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.appFont(.regular, size: 13))
                .foregroundColor(.yellow)
                .frame(width: 20)
            Text(text)
                .font(.appFont(.regular, size: 13))
                .foregroundColor(.white)
        }
    }
}

// MARK: - PostPublicToggle
// 投稿公開設定のToggle（カレンダーのみ公開は不可）

struct PostPublicToggle: View {
    @State private var isPublic: Bool = true  // デフォルト公開
    @State private var isLoading: Bool = false
    private let db = Firestore.firestore()
    private var uid: String { FirebaseAuth.Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        Toggle(isOn: $isPublic) {
            HStack(spacing: 8) {
                Image(systemName: isPublic ? "globe" : "lock.fill")
                    .foregroundColor(isPublic ? .accentBlue : Color(.systemGray))
                VStack(alignment: .leading, spacing: 2) {
                    Text("投稿を公開する")
                        .font(.appFont(.medium, size: 15))
                    Text(isPublic ? "タイムラインに表示されます" : "投稿は非公開です")
                        .font(.appFont(.regular, size: 12))
                        .foregroundColor(Color(.systemGray))
                }
            }
        }
        .tint(.accentBlue)
        .onChange(of: isPublic) { newValue in
            Task { await saveSetting(isPublic: newValue) }
        }
        .task { await loadSetting() }
        .disabled(isLoading)
    }

    private func loadSetting() async {
        isLoading = true
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            // デフォルトは公開（true）
            isPublic = doc.data()?["posts_are_public"] as? Bool ?? true
        } catch {}
        isLoading = false
    }

    private func saveSetting(isPublic: Bool) async {
        isLoading = true
        do {
            // 投稿非公開にした場合、カレンダーも非公開にする（カレンダーのみ公開は不可）
            if !isPublic {
                try await db.collection("users").document(uid).updateData([
                    "posts_are_public": false,
                    "calendar_is_public": false
                ])
            } else {
                try await db.collection("users").document(uid).updateData([
                    "posts_are_public": true
                ])
            }
        } catch {}
        isLoading = false
    }
}
