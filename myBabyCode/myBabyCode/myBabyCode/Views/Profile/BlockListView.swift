// =============================================================================
// ファイル名: BlockListView.swift
// 役割: ブロック中のユーザー一覧表示・ブロック解除
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BlockListView: View {
    @ObservedObject private var blockService = BlockService.shared
    @State private var blockedUsers: [AppUser] = []
    @State private var isLoading = false
    @State private var unblockTargetId: String? = nil
    @State private var showUnblockAlert = false

    private let db = Firestore.firestore()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised.slash")
                        .font(.appFont(.medium, size: 48))
                        .foregroundColor(Color(.systemGray4))
                    Text("ブロック中のユーザーはいません")
                        .font(.appFont(.regular, size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(blockedUsers, id: \.user_id) { user in
                        HStack(spacing: 12) {
                            let avatarId = user.avatar_id ?? "zou"
                            let bgColor = Color(hex: user.avatar_bg_color ?? "#FFEEBA")
                            Group {
                                if avatarId.hasPrefix("https://") {
                                    AsyncImage(url: URL(string: avatarId)) { img in
                                        img.resizable().scaledToFill()
                                    } placeholder: { Color.ecruBackground }
                                } else if avatarImageNames.contains(avatarId) {
                                    Image(avatarId).resizable().scaledToFill()
                                } else {
                                    Text(avatarId).font(.appFont(.regular, size: 24))
                                }
                            }
                            .frame(width: 44, height: 44)
                            .background(bgColor)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.display_name ?? "Unknown")
                                    .font(.appFont(.medium, size: 15))
                                if let uid = user.unique_user_id {
                                    Text("@\(uid)")
                                        .font(.appFont(.medium, size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Button {
                                unblockTargetId = user.user_id
                                showUnblockAlert = true
                            } label: {
                                Text("解除")
                                    .font(.appFont(.regular, size: 13))
                                    .foregroundColor(.accentRed)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.accentRed.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("ブロックリスト")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
        .alert("ブロックを解除しますか？", isPresented: $showUnblockAlert) {
            Button("解除する", role: .destructive) {
                if let targetId = unblockTargetId {
                    Task {
                        try? await blockService.unblockUser(targetUserId: targetId)
                        await loadBlockedUsers()
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("ブロックを解除すると、このユーザーの投稿がフィードに表示されるようになります。")
        }
    }

    private func loadBlockedUsers() async {
        isLoading = true
        await blockService.fetchBlockedUsers()
        let ids = Array(blockService.blockedUserIds)
        guard !ids.isEmpty else {
            blockedUsers = []
            isLoading = false
            return
        }
        var users: [AppUser] = []
        for uid in ids {
            if let doc = try? await db.collection("users").document(uid).getDocument(),
               let user = try? doc.data(as: AppUser.self) {
                users.append(user)
            }
        }
        blockedUsers = users.sorted { ($0.display_name ?? "") < ($1.display_name ?? "") }
        isLoading = false
    }
}
