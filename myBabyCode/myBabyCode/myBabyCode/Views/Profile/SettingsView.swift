import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var draftManager: DraftManager
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showReauthAlert = false
    @State private var reauthPassword = ""

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
                        Label("プロフィールを編集", systemImage: "person.crop.circle")
                    }
                } header: {
                    Text("アカウント")
                }

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
