// =============================================================================
// ファイル名: PublicCalendarView.swift
// 役割: 他ユーザーの公開カレンダーを閲覧する画面（読み取り専用）
// =============================================================================

import SwiftUI
import FirebaseFirestore

struct PublicCalendarView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [String: CalendarEntry] = [:]
    @State private var profileUser: AppUser?
    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var postsByDate: [String: [Post]] = [:]
    @State private var isLoading = false

    private let db = Firestore.firestore()
    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        return f
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    monthHeader
                    weekdayHeader
                    calendarGrid
                    if let date = selectedDate {
                        selectedDayPanel(date: date)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("\(profileUser?.display_name ?? profileUser?.unique_user_id ?? "ユーザー")のカレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task {
                await loadUser()
                await loadEntries()
                await loadPosts()
            }
            .onChange(of: displayedMonth) { _ in
                Task {
                    await loadEntries()
                    await loadPosts()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Month header
    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.appFont(.medium, size: 18))
                    .foregroundColor(.accentRed)
                    .padding(10)
            }
            Spacer()
            Text(monthTitle)
                .font(.appFont(.bold, size: 18))
            Spacer()
            Button {
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                if next <= Date() { displayedMonth = next }
            } label: {
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                Image(systemName: "chevron.right")
                    .font(.appFont(.medium, size: 18))
                    .foregroundColor(next > Date() ? Color(.systemGray4) : .accentRed)
                    .padding(10)
            }
            .disabled({
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                return next > Date()
            }())
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
    }

    // MARK: - Weekday row
    private var weekdayHeader: some View {
        let labels = ["日", "月", "火", "水", "木", "金", "土"]
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(labels[i])
                    .font(.appFont(.medium, size: 12))
                    .foregroundColor(i == 0 ? .accentRed : i == 6 ? .accentBlue : Color(.systemGray))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    // MARK: - Calendar grid
    private var calendarGrid: some View {
        let cal = Calendar.current
        let firstWeekday = cal.firstWeekdayOfMonth(for: displayedMonth)
        let offset = (firstWeekday - 1 + 7) % 7
        let totalDays = cal.daysInMonth(for: displayedMonth)
        let cells = offset + totalDays
        let rows = Int(ceil(Double(cells) / 7.0))

        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellIndex = row * 7 + col
                        let dayNum = cellIndex - offset + 1
                        if dayNum >= 1 && dayNum <= totalDays,
                           let date = dateFor(day: dayNum) {
                            PublicCalendarDayCell(
                                date: date,
                                entry: entries[Self.dateKey(for: date)],
                                postCount: postsByDate[Self.dateKey(for: date)]?.count ?? 0,
                                isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                isToday: Calendar.current.isDateInToday(date),
                                weekdayColumn: col
                            )
                            .onTapGesture {
                                if date <= Date() { selectedDate = date }
                            }
                        } else {
                            Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Selected day panel
    @ViewBuilder
    private func selectedDayPanel(date: Date) -> some View {
        let key = Self.dateKey(for: date)
        let entry = entries[key]

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDayTitle(date))
                    .font(.appFont(.bold, size: 16))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // この日の公開投稿一覧
            if let posts = postsByDate[key], !posts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("この日の投稿 \(posts.count)件")
                        .font(.appFont(.medium, size: 14))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                    ForEach(posts, id: \.post_id) { post in
                        PostThumbnailCard(post: post)
                    }
                }
                .padding(.top, 4)
            }

            if let entry = entry {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            if let w = entry.weather_type.flatMap({ WeatherType(rawValue: $0) }) {
                                HStack(spacing: 4) {
                                    Text(w.emoji).font(.appFont(.regular, size: 16))
                                    if let max = entry.temp_max, let min = entry.temp_min {
                                        Text("\(Int(max.rounded()))° / \(Int(min.rounded()))°")
                                            .font(.appFont(.regular, size: 13))
                                            .foregroundColor(Color(.systemGray))
                                    }
                                }
                            }
                            if !entry.comment.isEmpty {
                                Text(entry.comment)
                                    .font(.appFont(.regular, size: 14))
                                    .lineLimit(4)
                                    .foregroundColor(.primary)
                            }
                        }
                        Spacer()
                        if let urlStr = entry.photo_url, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color(.systemGray5)
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                .padding(.horizontal, 12)
            } else {
                Text("この日の記録はありません")
                    .font(.appFont(.regular, size: 13))
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
    }

    // MARK: - Helpers
    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: displayedMonth)
    }

    private func selectedDayTitle(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日（E）"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: date)
    }

    private func dateFor(day: Int) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        return Calendar.current.date(from: comps)
    }

    private static func dateKey(for date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    // MARK: - Data loading
    private func loadPosts() async {
        isLoading = true
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(for: displayedMonth)),
              let end = cal.date(byAdding: .month, value: 2, to: cal.startOfMonth(for: displayedMonth)) else { return }

        do {
            let snap = try await db.collection("posts")
                .whereField("user_id", isEqualTo: userId)
                .whereField("is_hidden", isEqualTo: false)
                .whereField("created_at", isGreaterThanOrEqualTo: Timestamp(date: start))
                .whereField("created_at", isLessThan: Timestamp(date: end))
                .order(by: "created_at", descending: true)
                .getDocuments()
            var grouped: [String: [Post]] = [:]
            for doc in snap.documents {
                if let post = try? doc.data(as: Post.self) {
                    let dateKey = Self.dateKeyFormatter.string(from: post.created_at.dateValue())
                    grouped[dateKey, default: []].append(post)
                }
            }
            postsByDate = grouped
        } catch {}
        isLoading = false
    }

    private func loadUser() async {
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            profileUser = try doc.data(as: AppUser.self)
        } catch {}
    }

    private func loadEntries() async {
        isLoading = true
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .month, value: -1, to: cal.startOfMonth(for: displayedMonth)),
              let end = cal.date(byAdding: .month, value: 2, to: cal.startOfMonth(for: displayedMonth)) else { return }
        let startKey = Self.dateKeyFormatter.string(from: start)
        let endKey = Self.dateKeyFormatter.string(from: end)

        do {
            let snap = try await db.collection("calendar_entries")
                .document(userId)
                .collection("entries")
                .whereField("date_key", isGreaterThanOrEqualTo: startKey)
                .whereField("date_key", isLessThan: endKey)
                .whereField("is_public", isEqualTo: true)
                .getDocuments()
            var loaded: [String: CalendarEntry] = [:]
            for doc in snap.documents {
                if let entry = try? doc.data(as: CalendarEntry.self) {
                    loaded[entry.date_key] = entry
                }
            }
            entries = loaded
        } catch {}
        isLoading = false
    }
}

// MARK: - PublicCalendarDayCell
struct PublicCalendarDayCell: View {
    let date: Date
    let entry: CalendarEntry?
    let postCount: Int
    let isSelected: Bool
    let isToday: Bool
    let weekdayColumn: Int

    private var isFuture: Bool { date > Date() }
    private var hasContent: Bool { entry != nil || postCount > 0 }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentRed)
                        .frame(width: 32, height: 32)
                } else if isToday {
                    Circle()
                        .strokeBorder(Color.accentRed, lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.appFont(isToday ? .bold : .regular, size: 14))
                    .foregroundColor(dayTextColor)
            }
            .frame(width: 32, height: 32)

            if let w = entry?.weather_type.flatMap({ WeatherType(rawValue: $0) }) {
                Text(w.emoji)
                    .font(.appFont(.bold, size: 10))
            } else {
                Color.clear.frame(height: 12)
            }

            HStack(spacing: 4) {
                if let max = entry?.temp_max {
                    Text("\(Int(max.rounded()))°")
                        .font(.appFont(.regular, size: 9))
                        .foregroundColor(Color(.systemGray2))
                }
                if postCount > 0 {
                    Text("\(postCount)")
                        .font(.appFont(.regular, size: 9))
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14)
                        .background(Color.accentBlue)
                        .clipShape(Circle())
                }
            }
            .frame(height: 10)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentRed.opacity(0.08))
                } else if hasContent {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.7))
                } else {
                    Color.clear
                }
            }
        )
        .opacity(isFuture ? 0.3 : 1.0)
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if isFuture { return Color(.systemGray3) }
        if weekdayColumn == 0 { return .accentRed }
        if weekdayColumn == 6 { return .accentBlue }
        return .primary
    }
}

