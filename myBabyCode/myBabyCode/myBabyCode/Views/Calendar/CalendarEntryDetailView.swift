// =============================================================================
// ファイル名: CalendarEntryDetailView.swift
// 役割: 日記詳細表示画面（写真拡大・天気情報・コメント表示・削除）
// 説明:
//   カレンダーの日付セルをタップした際に表示される日記詳細画面です。
//   投稿詳細画面（PostDetailView）と同様のフォーマットで、
//   写真、天気・気温情報、日記コメントを表示します。
//   自分の日記の場合はゴミ箱アイコンから削除が可能です。
// =============================================================================

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

struct CalendarEntryDetailView: View {
    // === 入力パラメータ ===
    let entry: CalendarEntry                    // 表示対象の日記エントリー
    var onDeleted: ((CalendarEntry) -> Void)? = nil  // 削除完了後のコールバック

    // === 環境オブジェクト ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // === 内部状態 ===
    @State private var showDeleteConfirm = false    // 削除確認アラートの表示状態
    @State private var isDeleting = false           // 削除処理中フラグ

    // 日付フォーマッター
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy年M月d日"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }

    // 日付キーから日付文字列を生成
    private var displayDate: String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        inputFormatter.locale = Locale(identifier: "ja_JP")
        
        if let date = inputFormatter.date(from: entry.date_key) {
            return dateFormatter.string(from: date)
        }
        return entry.date_key
    }

    // 天気タイプの変換
    private var weatherType: WeatherType? {
        entry.weather_type.flatMap { WeatherType(rawValue: $0) }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 写真表示
                    photoSection

                    VStack(alignment: .leading, spacing: 20) {
                        // 日付と天気情報
                        dateAndWeatherSection

                        // コメントセクション
                        commentSectionView

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("日記詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                // 自分の日記の場合のみ削除ボタンを表示
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if entry.user_id == Auth.currentUID {
                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
            }
            .alert("日記を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) {
                    Task { await deleteEntry() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この日記と写真が永久に削除されます。この操作は取り消せません。")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Photo Section
    @ViewBuilder
    private var photoSection: some View {
        if let photoURL = entry.photo_url, !photoURL.isEmpty,
           let url = URL(string: photoURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: UIScreen.main.bounds.width)
                case .failure(_):
                    placeholderView
                case .empty:
                    Color(.systemGray5)
                        .overlay(ProgressView())
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            placeholderView
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 0)
            .fill(Color(.systemGray6))
            .frame(height: UIScreen.main.bounds.width * 0.6)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.appFont(.regular, size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("写真はありません")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.secondary)
                }
            )
    }

    // MARK: - Date and Weather Section
    private var dateAndWeatherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 日付
            Text(displayDate)
                .font(.appFont(.bold, size: 18))
                .foregroundColor(.primary)

            // 天気・気温バッジ
            HStack(spacing: 12) {
                // 天気アイコン
                if let wt = weatherType {
                    HStack(spacing: 4) {
                        Image(systemName: wt.sfSymbol)
                            .font(.appFont(.regular, size: 14))
                        Text(wt.rawValue)
                            .font(.appFont(.regular, size: 13))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(weatherBadgeColor)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }

                // 気温
                if let max = entry.temp_max, let min = entry.temp_min {
                    HStack(spacing: 4) {
                        Text("\(Int(max.rounded()))°")
                            .font(.appFont(.medium, size: 13))
                            .foregroundColor(.red.opacity(0.7))
                        Text("/")
                            .font(.appFont(.medium, size: 13))
                            .foregroundColor(.secondary)
                        Text("\(Int(min.rounded()))°")
                            .font(.appFont(.regular, size: 13))
                            .foregroundColor(.blue.opacity(0.7))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Comment Section
    @ViewBuilder
    private var commentSectionView: some View {
        if !entry.comment.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("コメント")
                    .font(.appFont(.bold, size: 14))
                    .foregroundColor(.secondary)

                Text(entry.comment)
                    .font(.appFont(.regular, size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
        }
    }

    // MARK: - Weather Badge Color
    private var weatherBadgeColor: Color {
        guard let wt = weatherType else {
            return Color(.systemGray5)
        }
        switch wt {
        case .sunny:  return Color.orange.opacity(0.3)
        case .cloudy: return Color.gray.opacity(0.3)
        case .rainy:  return Color.blue.opacity(0.3)
        case .snowy:  return Color.cyan.opacity(0.3)
        }
    }

    // MARK: - Delete Entry
    private func deleteEntry() async {
        guard entry.user_id == Auth.currentUID else { return }
        
        isDeleting = true
        defer { isDeleting = false }
        
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        do {
            // Firestoreから削除
            try await db.collection("calendar_entries")
                .document(entry.user_id)
                .collection("entries")
                .document(entry.date_key)
                .delete()
            
            // Storageの写真も削除（あれば）
            if entry.photo_url != nil {
                let imgRef = storage.reference().child("calendar/\(entry.user_id)/\(entry.date_key).jpg")
                try? await imgRef.delete()
            }
            
            // 削除コールバック
            onDeleted?(entry)
            
            // 画面を閉じる
            dismiss()
        } catch {
            print("[DEBUG] CalendarEntryDetailView delete error: \(error)")
        }
    }
}
