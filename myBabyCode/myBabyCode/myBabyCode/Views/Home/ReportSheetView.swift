// =============================================================================
// ファイル名: ReportSheetView.swift
// 役割: 投稿・ユーザー通報理由選択シート
// =============================================================================

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

enum ReportTargetType: String {
    case post = "post"
    case user = "user"
}

struct ReportSheetView: View {
    let targetType: ReportTargetType
    let targetId: String
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: String? = nil
    @State private var isSubmitting = false
    @State private var showDone = false

    private let reasons: [String] = [
        "スパム・宣伝",
        "嫌がらせ・いじめ",
        "不適切なコンテンツ",
        "著作権侵害",
        "偽情報・誤情報",
        "その他"
    ]

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                Text(targetType == .post ? "この投稿を通報する理由を選択してください" : "このユーザーを通報する理由を選択してください")
                    .font(.appFont(.regular, size: 14))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                ForEach(reasons, id: \.self) { reason in
                    Button {
                        selectedReason = reason
                    } label: {
                        HStack {
                            Text(reason)
                                .font(.appFont(.regular, size: 15))
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentRed)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 20)
                }

                Spacer()

                Button {
                    guard let reason = selectedReason else { return }
                    Task { await submitReport(reason: reason) }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("通報する")
                                .font(.appFont(.bold, size: 16))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(selectedReason != nil ? Color.accentRed : Color.secondary.opacity(0.3))
                    .cornerRadius(14)
                }
                .disabled(selectedReason == nil || isSubmitting)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .navigationTitle(targetType == .post ? "投稿を通報" : "ユーザーを通報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("通報を受け付けました", isPresented: $showDone) {
                Button("OK") {
                    onComplete?()
                    dismiss()
                }
            } message: {
                Text("ご報告ありがとうございます。内容を確認いたします。")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func submitReport(reason: String) async {
        isSubmitting = true
        defer { isSubmitting = false }
        guard let uid = FirebaseAuth.Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        do {
            try await db.collection("reports").addDocument(data: [
                "report_type": targetType.rawValue,
                "target_id": targetId,
                "reason": reason,
                "reporter_id": uid,
                "created_at": Timestamp()
            ])
            showDone = true
        } catch {
            print("[ReportSheetView] submit error: \(error)")
        }
    }
}
