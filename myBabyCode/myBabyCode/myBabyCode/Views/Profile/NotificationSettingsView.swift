// =============================================================================
// ファイル名: NotificationSettingsView.swift
// 役割: 通知設定画面（各通知のON/OFF切り替え）
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotificationSettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var isLoading = false
    @State private var isSaving = false

    // 通知設定
    @State private var notifyLikes: Bool = true
    @State private var notifyFollows: Bool = true
    @State private var notifyComments: Bool = true
    @State private var notifyDiaryReminder: Bool = false

    private let db = Firestore.firestore()
    private var uid: String { FirebaseAuth.Auth.auth().currentUser?.uid ?? "" }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $notifyLikes) {
                    Label("いいね", systemImage: "heart")
                }
                Toggle(isOn: $notifyFollows) {
                    Label("フォロー", systemImage: "person.badge.plus")
                }
            } header: {
                Text("アクティビティ")
            } footer: {
                Text("自分の投稿にいいねやフォローがあった際に通知します。")
            }

            Section {
                Toggle(isOn: $notifyDiaryReminder) {
                    Label("日記リマインダー", systemImage: "bell.badge")
                }
            } header: {
                Text("リマインダー")
            } footer: {
                Text("その日に日記を書いていない場合に通知します。通知時刻はカレンダー設定から変更できます。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("通知の設定")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading { ProgressView() }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isSaving {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button(action: {
                        Task { await saveSettings() }
                    }) {
                        Text("保存")
                            .font(.appFont(.medium, size: 17))
                            .foregroundColor(.accentRed)
                    }
                }
            }
        }
        .task {
            await loadSettings()
        }
    }

    private func loadSettings() async {
        isLoading = true
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            let data = doc.data() ?? [:]
            notifyLikes = data["notify_likes"] as? Bool ?? true
            notifyFollows = data["notify_follows"] as? Bool ?? true
            notifyComments = data["notify_comments"] as? Bool ?? true
            notifyDiaryReminder = data["notify_diary_reminder"] as? Bool ?? false
        } catch {}
        isLoading = false
    }

    private func saveSettings() async {
        isSaving = true
        do {
            try await db.collection("users").document(uid).updateData([
                "notify_likes": notifyLikes,
                "notify_follows": notifyFollows,
                "notify_comments": notifyComments,
                "notify_diary_reminder": notifyDiaryReminder
            ])
        } catch {}
        isSaving = false
    }
}

