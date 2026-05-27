// =============================================================================
// ファイル名: SettingsView.swift
// 役割: 設定画面（プロフィール編集・下書き一覧・規約・ログアウト・アカウント削除）
// 説明:
//   マイページの歯車アイコンから遷移する設定画面です。
//   List形式で各種設定項目を表示し、プロフィール編集、下書き一覧、利用規約・
//   プライバシーポリシー閲覧、ログアウト、アカウント削除の各機能へ導きます。
// =============================================================================

import SwiftUI

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
                } header: {
                    Text("アカウント")
                }

                // --- 投稿セクション ---
                Section {
                    NavigationLink(destination: DraftListView(onDraftSelected: { dismiss() })
                        .environmentObject(draftManager)) {
                        HStack {
                            Label("下書き一覧", systemImage: "doc.text")
                            Spacer()
                            let count = draftManager.drafts.count
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 12, weight: .semibold))
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
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.accentGreen)
                                .cornerRadius(10)
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
                                } else {
                                    Text("近日公開")
                                        .font(.system(size: 12, weight: .semibold))
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
                    Text("広告を非表示にするプレミアムプランです。購入はApp Store経由で行われます。")
                        .font(.caption)
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

                // --- その他セクション ---
                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Label("アカウントを削除", systemImage: "person.crop.circle.badge.minus")
                    }
                } header: {
                    Text("その他")
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
                    } else if authViewModel.isEmailUser {
                        // Emailユーザーはパスワード入力
                        showReauthAlert = true
                    } else {
                        // その他（Apple等）は再ログインを促す
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
        }
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
                            .font(.system(size: 36))
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
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            HStack(spacing: 10) {
                                Text(formattedDate(draft.savedAt))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                if !draft.items.isEmpty {
                                    Text("\(draft.items.count)アイテム")
                                        .font(.system(size: 11))
                                        .foregroundColor(.accentBlue)
                                }
                                let wt = WeatherType(rawValue: draft.weatherType)
                                Label("\(draft.tempMax)℃/\(draft.tempMin)℃", systemImage: wt?.sfSymbol ?? "cloud.sun")
                                    .font(.system(size: 11))
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
                            .font(.system(size: 22))
                            .foregroundColor(.yellow)
                        Text("プレミアムプラン")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("広告を完全に非表示にして\nすっきり快適に使えます")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    // 特典リスト
                    VStack(alignment: .leading, spacing: 6) {
                        PremiumFeatureRow(icon: "nosign", text: "全広告を非表示")
                        PremiumFeatureRow(icon: "bolt.fill", text: "タイムラインがすっきり表示")
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
                                .font(.system(size: 15))
                        }
                        Text(isPurchasing ? "処理中..." : "プレミアムに登録する")
                            .font(.system(size: 16, weight: .bold))
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
                        .font(.system(size: 13))
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

// MARK: - PremiumFeatureRow
// プレミアムバナー内の特典1行表示

private struct PremiumFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.yellow)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white)
        }
    }
}
