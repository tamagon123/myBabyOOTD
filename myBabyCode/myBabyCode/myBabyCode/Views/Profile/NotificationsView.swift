// =============================================================================
// ファイル名: NotificationsView.swift
// 役割: 通知一覧画面
// 説明:
//   Firestore の notifications コレクションから自分宛ての通知を取得し、
//   時系列順に一覧表示する。画面を開いた時点で全通知が既読にマークされる。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotificationsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false

    private var uid: String { Auth.currentUID }

    var body: some View {
        List {
            if isLoading && notifications.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if notifications.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "bell.slash")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("通知はありません")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                }
            } else {
                ForEach(notifications) { notif in
                    notificationRow(notif)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("通知")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.accentRed)
                }
                .opacity(notifications.isEmpty ? 0 : 1)
                .disabled(notifications.isEmpty)
            }
        }
        .alert("すべての通知を削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除", role: .destructive) {
                Task { await deleteAll() }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除した通知は元に戻せません")
        }
        .task {
            await loadNotifications()
        }
        .refreshable {
            await loadNotifications()
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Row

    private func notificationRow(_ notif: AppNotification) -> some View {
        HStack(spacing: 12) {
            // アイコン
            Image(systemName: iconForType(notif.type))
                .font(.system(size: 22))
                .foregroundColor(colorForType(notif.type))
                .frame(width: 40, height: 40)
                .background(colorForType(notif.type).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(notif.title)
                    .font(.system(size: 15, weight: .medium))
                Text(notif.body)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                if let date = notif.created_at.dateValue() as Date? {
                    Text(timeAgo(from: date))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }

            Spacer()

            // 未読インジケータ
            if !notif.is_read {
                Circle()
                    .fill(Color.accentRed)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
        .background(notif.is_read ? Color.clear : Color.accentRed.opacity(0.03))
    }

    // MARK: - Load

    private func loadNotifications() async {
        guard !uid.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snap = try await Firestore.firestore()
                .collection("notifications")
                .whereField("user_id", isEqualTo: uid)
                .order(by: "created_at", descending: true)
                .limit(to: 100)
                .getDocuments()

            notifications = snap.documents.compactMap { try? $0.data(as: AppNotification.self) }

            // 画面を開いたら全通知を既読にする
            await NotificationService.shared.markAllAsRead(uid: uid)
            // UI上も即時反映
            notifications = notifications.map {
                var n = $0
                n.is_read = true
                return n
            }
        } catch {
            errorMessage = "通知の取得に失敗しました"
            print("[NotificationsView] load error: \(error)")
        }
    }

    // MARK: - Delete All

    private func deleteAll() async {
        await NotificationService.shared.deleteAllNotifications(uid: uid)
        await MainActor.run {
            notifications = []
        }
        NotificationCenter.default.post(name: Notification.Name("NotificationsDeleted"), object: nil)
    }

    // MARK: - Helpers

    private func iconForType(_ type: String) -> String {
        switch type {
        case "new_post": return "doc.text"
        case "like": return "heart.fill"
        case "follow": return "person.badge.plus"
        case "diary_reminder": return "bell.badge"
        default: return "bell"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "new_post": return .blue
        case "like": return .pink
        case "follow": return .green
        case "diary_reminder": return .orange
        default: return .gray
        }
    }

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
