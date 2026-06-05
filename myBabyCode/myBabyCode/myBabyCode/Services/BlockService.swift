// =============================================================================
// ファイル名: BlockService.swift
// 役割: ユーザーブロック機能（Firestore保存・取得・キャッシュ管理）
// =============================================================================

import Foundation
import Combine
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class BlockService: ObservableObject {
    @Published var blockedUserIds: Set<String> = []

    private let db = Firestore.firestore()
    static let shared = BlockService()

    private init() {}

    // ブロック済みIDリストをFirestoreから取得
    func fetchBlockedUsers() async {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        do {
            let snap = try await db.collection("blocks")
                .whereField("blocker_id", isEqualTo: uid)
                .getDocuments()
            let ids = snap.documents.compactMap { $0.data()["blocked_id"] as? String }
            blockedUserIds = Set(ids)
        } catch {
            print("[BlockService] fetchBlockedUsers error: \(error)")
        }
    }

    // ユーザーをブロック
    func blockUser(targetUserId: String) async throws {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let docId = "\(uid)_\(targetUserId)"
        try await db.collection("blocks").document(docId).setData([
            "blocker_id": uid,
            "blocked_id": targetUserId,
            "created_at": Timestamp()
        ])
        blockedUserIds.insert(targetUserId)
    }

    // ブロック解除
    func unblockUser(targetUserId: String) async throws {
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let docId = "\(uid)_\(targetUserId)"
        try await db.collection("blocks").document(docId).delete()
        blockedUserIds.remove(targetUserId)
    }

    // ブロック済みかどうか確認
    func isBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }
}
