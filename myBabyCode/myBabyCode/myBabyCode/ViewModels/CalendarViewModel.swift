// =============================================================================
// ファイル名: CalendarViewModel.swift
// 役割: カレンダー機能のデータ管理（エントリー取得・保存・削除・天気取得）
// =============================================================================

import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var entries: [String: CalendarEntry] = [:]       // dateKey → CalendarEntry
    @Published var postsByDate: [String: [Post]] = [:]        // dateKey → その日の投稿一覧
    @Published var calendarIsPublic: Bool = false               // カレンダー公開設定
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var monthlyWeather: [String: WeatherResult] = [:] // dateKey → 月全体の天気データ

    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var lastFetchedMonth: String? = nil                 // キャッシュ用: 最後に取得した月
    private var lastFetchedRegion: String? = nil                // キャッシュ用: 最後に取得した地域

    // 日付フォーマッター（"yyyy-MM-dd"）
    static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()

    // 編集可能な最大過去日数（サブスク: 2日、無課金: 7日）
    func maxEditableDays(isSubscribed: Bool) -> Int {
        isSubscribed ? 2 : 7
    }

    // 指定日が編集可能かどうか
    func canEdit(_ date: Date, isSubscribed: Bool) -> Bool {
        guard date <= Date() else { return false }
        let diff = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return diff <= maxEditableDays(isSubscribed: isSubscribed)
    }

    // MARK: - Load

    // 指定月（前後1ヶ月含む）のエントリーをFirestoreから取得
    func fetchEntries(uid: String, around month: Date) async {
        isLoading = true
        defer { isLoading = false }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(for: month)),
              let end = cal.date(byAdding: .month, value: 2, to: cal.startOfMonth(for: month)) else { return }

        let startKey = Self.dateKeyFormatter.string(from: start)
        let endKey   = Self.dateKeyFormatter.string(from: end)
        print("[DEBUG] fetchEntries: uid=\(uid), startKey=\(startKey), endKey=\(endKey)")

        do {
            let snap = try await db.collection("calendar_entries")
                .document(uid)
                .collection("entries")
                .whereField("date_key", isGreaterThanOrEqualTo: startKey)
                .whereField("date_key", isLessThan: endKey)
                .getDocuments()
            print("[DEBUG] fetchEntries: fetched \(snap.documents.count) entries")
            var loaded: [String: CalendarEntry] = entries
            for doc in snap.documents {
                if let entry = try? doc.data(as: CalendarEntry.self) {
                    print("[DEBUG] Entry: date_key=\(entry.date_key), weather=\(entry.weather_type ?? "nil")")
                    loaded[entry.date_key] = entry
                }
            }
            entries = loaded
            print("[DEBUG] fetchEntries: total entries=\(entries.count)")
        } catch {
            print("[DEBUG] fetchEntries error: \(error)")
            errorMessage = "データの取得に失敗しました"
        }
    }

    // 指定月の投稿を取得し、日付ごとにグループ化
    func fetchPosts(uid: String, around month: Date) async {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(for: month)),
              let end = cal.date(byAdding: .month, value: 2, to: cal.startOfMonth(for: month)) else { return }

        do {
            let snap = try await db.collection("posts")
                .whereField("user_id", isEqualTo: uid)
                .whereField("created_at", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("created_at", isLessThan: Timestamp(date: end))
                .order(by: "created_at", descending: true)
                .getDocuments()
            print("[DEBUG] Calendar fetchPosts: fetched \(snap.documents.count) posts for uid=\(uid), range=\(start) to \(end)")
            var grouped: [String: [Post]] = [:]
            for doc in snap.documents {
                if let post = try? doc.data(as: Post.self) {
                    let dateKey = Self.dateKeyFormatter.string(from: post.created_at.dateValue())
                    print("[DEBUG] Post: id=\(post.post_id), created_at=\(post.created_at.dateValue()), dateKey=\(dateKey)")
                    grouped[dateKey, default: []].append(post)
                }
            }
            postsByDate = grouped
            print("[DEBUG] Calendar postsByDate keys: \(grouped.keys.sorted())")
        } catch {
            print("[DEBUG] Calendar fetchPosts error: \(error)")
        }
    }

    // カレンダー公開設定を取得
    func fetchCalendarPublicSetting(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            calendarIsPublic = doc.data()?["calendar_is_public"] as? Bool ?? false
        } catch {}
    }

    // 月全体の天気データを取得（キャッシュ機能付き）
    func fetchMonthlyWeather(regionCode: String, month: Date) async {
        let monthKey = Self.dateKeyFormatter.string(from: month)
        // 同じ月・同じ地域なら再取得しない
        if lastFetchedMonth == monthKey && lastFetchedRegion == regionCode && !monthlyWeather.isEmpty {
            print("[DEBUG] fetchMonthlyWeather: using cached data for \(monthKey)")
            return
        }
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(for: month)),
              let end = cal.date(byAdding: .month, value: 2, to: cal.startOfMonth(for: month)) else { return }
        
        print("[DEBUG] fetchMonthlyWeather: fetching from \(start) to \(end)")
        let weatherData = await WeatherService.shared.fetchMonthly(regionCode: regionCode, startDate: start, endDate: end)
        monthlyWeather = weatherData
        lastFetchedMonth = monthKey
        lastFetchedRegion = regionCode
        print("[DEBUG] fetchMonthlyWeather: cached \(weatherData.count) days")
    }

    // MARK: - Save

    // エントリーを保存（新規 or 更新）
    func saveEntry(
        uid: String,
        dateKey: String,
        comment: String,
        image: UIImage?,
        regionCode: String
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let now = Timestamp(date: Date())
            var photoURL: String? = entries[dateKey]?.photo_url

            // 新しい画像があればアップロード（失敗しても Firestore 保存は続行）
            if let img = image, let data = jpegData(from: img) {
                do {
                    let ref = storage.reference().child("calendar/\(uid)/\(dateKey).jpg")
                    _ = try await ref.putDataAsync(data)
                    photoURL = try await ref.downloadURL().absoluteString
                } catch {
                    print("[DEBUG] Calendar image upload failed (non-fatal): \(error)")
                }
            }

            let existing = entries[dateKey]
            // 既存エントリーのコメントがあれば保持（上書きしない）
            let finalComment = (existing?.comment.isEmpty == false) ? existing!.comment : comment
            let entry = CalendarEntry(
                id: existing?.id,
                date_key: dateKey,
                user_id: uid,
                comment: finalComment,
                photo_url: photoURL,
                weather_type: existing?.weather_type,
                temp_max: existing?.temp_max,
                temp_min: existing?.temp_min,
                is_public: calendarIsPublic,
                created_at: existing?.created_at ?? now,
                updated_at: now
            )

            let ref = db.collection("calendar_entries").document(uid).collection("entries").document(dateKey)
            try ref.setData(from: entry, merge: false)
            entries[dateKey] = entry
            print("[DEBUG] Calendar saveEntry success: \(dateKey), comment=\(comment), photo_url=\(photoURL ?? "nil")")
            return true
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            print("[DEBUG] Calendar saveEntry FAILED: \(error)")
            return false
        }
    }

    // 天気データをエントリーに更新（新規作成時も対応）
    func updateWeather(uid: String, dateKey: String, weather: WeatherResult) async {
        var entry = entries[dateKey] ?? CalendarEntry(
            id: nil,
            date_key: dateKey,
            user_id: uid,
            comment: "",
            photo_url: nil,
            weather_type: nil,
            temp_max: nil,
            temp_min: nil,
            is_public: calendarIsPublic,
            created_at: Timestamp(date: Date()),
            updated_at: Timestamp(date: Date())
        )
        entry.weather_type = weather.weatherType
        entry.temp_max = weather.tempMax
        entry.temp_min = weather.tempMin
        entry.updated_at = Timestamp(date: Date())
        entries[dateKey] = entry
        let ref = db.collection("calendar_entries").document(uid).collection("entries").document(dateKey)
        do {
            try ref.setData(from: entry, merge: false)
            print("[DEBUG] Calendar updateWeather success: \(dateKey), weather=\(weather.weatherType)")
        } catch {
            print("[DEBUG] Calendar updateWeather FAILED: \(error)")
        }
    }

    // カレンダー公開設定を保存
    func saveCalendarPublicSetting(uid: String, isPublic: Bool) async {
        calendarIsPublic = isPublic
        try? await db.collection("users").document(uid).updateData([
            "calendar_is_public": isPublic
        ])
    }

    // MARK: - Delete

    func deleteEntry(uid: String, dateKey: String) async {
        entries.removeValue(forKey: dateKey)
        let ref = db.collection("calendar_entries").document(uid).collection("entries").document(dateKey)
        try? await ref.delete()
        // Storage写真も削除（失敗しても続行）
        let imgRef = storage.reference().child("calendar/\(uid)/\(dateKey).jpg")
        try? await imgRef.delete()
    }

    // MARK: - Helpers

    private func jpegData(from image: UIImage) -> Data? {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return nil }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let type = CGImageSourceGetType(source) else { return data }
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else { return data }
        let removeMetadata: [String: Any] = [kCGImageDestinationMetadata as String: [:]]
        CGImageDestinationAddImageFromSource(dest, source, 0, removeMetadata as CFDictionary)
        CGImageDestinationFinalize(dest)
        return mutableData as Data
    }
}

// MARK: - Calendar extension
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }

    func daysInMonth(for date: Date) -> Int {
        range(of: .day, in: .month, for: date)?.count ?? 30
    }

    func firstWeekdayOfMonth(for date: Date) -> Int {
        let start = startOfMonth(for: date)
        return component(.weekday, from: start)
    }
}
