// =============================================================================
// ファイル名: CalendarView.swift
// 役割: カレンダー画面（月次表示・日付タップ・日記閲覧・新規投稿）
// =============================================================================

import SwiftUI
import FirebaseAuth

struct CalendarView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @State private var displayedMonth: Date = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }()
    @State private var selectedDate: Date? = nil
    @State private var showEntrySheet = false
    @State private var showNewPostSheet = false
    @State private var showPublicConfirm = false
    @State private var selectedPostForDetail: Post? = nil

    private var uid: String { Auth.currentUID }
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 上部: 地域名・公開設定
                topStatusBar

                ScrollView {
                    VStack(spacing: 0) {
                        monthHeader
                        weekdayHeader
                        calendarGrid
                        Divider().padding(.top, 8)
                        if let date = selectedDate {
                            selectedDayPanel(date: date)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("カレンダー")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEntrySheet, onDismiss: {
                Task {
                    await vm.fetchEntries(uid: uid, around: displayedMonth)
                    await vm.fetchPosts(uid: uid, around: displayedMonth)
                }
            }) {
                if let date = selectedDate {
                    CalendarEntryEditView(date: date, vm: vm, uid: uid)
                        .environmentObject(authViewModel)
                }
            }
            .alert("カレンダーを公開しますか？", isPresented: $showPublicConfirm) {
                Button("公開する", role: .none) {
                    Task { await vm.saveCalendarPublicSetting(uid: uid, isPublic: true) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("カレンダーの日記内容が他のユーザーに公開されます。")
            }
            .sheet(isPresented: $showNewPostSheet, onDismiss: {
                print("[DEBUG] CalendarView onDismiss fired (new post)")
                Task {
                    await vm.fetchEntries(uid: uid, around: displayedMonth)
                    await vm.fetchPosts(uid: uid, around: displayedMonth)
                    print("[DEBUG] CalendarView refetch done, entries.count=\(vm.entries.count), postsByDate.count=\(vm.postsByDate.count)")
                }
            }) {
                if let date = selectedDate {
                    CalendarNewPostBridge(date: date)
                        .environmentObject(authViewModel)
                }
            }
            .sheet(item: $selectedPostForDetail) { post in
                PostDetailView(post: post)
                    .environmentObject(authViewModel)
                    .environmentObject(postsViewModel)
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CalendarEntryUpdated"))) { _ in
                print("[DEBUG] CalendarView received CalendarEntryUpdated notification")
                Task {
                    await vm.fetchEntries(uid: uid, around: displayedMonth)
                    await vm.fetchPosts(uid: uid, around: displayedMonth)
                    print("[DEBUG] CalendarView notification refetch done, entries.count=\(vm.entries.count)")
                }
            }
            .task {
                print("[DEBUG] CalendarView task started")
                await vm.fetchCalendarPublicSetting(uid: uid)
                print("[DEBUG] CalendarView task: fetchCalendarPublicSetting done")
                await vm.fetchEntries(uid: uid, around: displayedMonth)
                print("[DEBUG] CalendarView task: fetchEntries done, entries.count=\(vm.entries.count)")
                await vm.fetchPosts(uid: uid, around: displayedMonth)
                print("[DEBUG] CalendarView task: fetchPosts done")
                // 月全体の天気データを取得
                if let regionCode = authViewModel.currentUser?.region_code {
                    await vm.fetchMonthlyWeather(regionCode: regionCode, month: displayedMonth)
                    print("[DEBUG] CalendarView task: fetchMonthlyWeather done, weather count=\(vm.monthlyWeather.count)")
                }
                print("[DEBUG] CalendarView task: all done")
            }
            .onChange(of: displayedMonth) { month in
                Task {
                    await vm.fetchEntries(uid: uid, around: month)
                    await vm.fetchPosts(uid: uid, around: month)
                    // 月変更時も天気データを取得
                    if let regionCode = authViewModel.currentUser?.region_code {
                        await vm.fetchMonthlyWeather(regionCode: regionCode, month: month)
                    }
                }
            }
        }
    }

    // MARK: - Top status bar (region + public toggle)
    private var topStatusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13))
                Text(regionName)
                    .font(.system(size: 14))
            }
            .foregroundColor(Color(.systemGray))

            Spacer()

            calendarPublicToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.ecruBackground)
    }

    // MARK: - Month header (prev/next arrows)
    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentRed)
                    .padding(10)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Spacer()
            Button {
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                if next <= Date() {
                    displayedMonth = next
                }
            } label: {
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(next > Date() ? Color(.systemGray4) : .accentRed)
                    .padding(10)
            }
            .disabled({
                let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                return next > Date()
            }())
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var regionName: String {
        guard let code = authViewModel.currentUser?.region_code,
              let index = Int(code),
              index >= 1 && index <= prefectures.count else {
            return "未設定"
        }
        return prefectures[index - 1]
    }

    // MARK: - Weekday row
    private var weekdayHeader: some View {
        let labels = ["日", "月", "火", "水", "木", "金", "土"]
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                Text(labels[i])
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(i == 0 ? .accentRed : i == 6 ? .accentBlue : Color(.systemGray))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    // MARK: - Calendar grid with grid lines
    private var calendarGrid: some View {
        let cal = Calendar.current
        let firstWeekday = cal.firstWeekdayOfMonth(for: displayedMonth)
        let offset = (firstWeekday - 1 + 7) % 7
        let totalDays = cal.daysInMonth(for: displayedMonth)
        let cells = offset + totalDays
        let rows = Int(ceil(Double(cells) / 7.0))

        return VStack(spacing: 0) {
            // Horizontal grid lines
            ForEach(0..<rows, id: \.self) { row in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let cellIndex = row * 7 + col
                            let dayNum = cellIndex - offset + 1
                            if dayNum >= 1 && dayNum <= totalDays,
                               let date = dateFor(day: dayNum) {
                                let dateKey = Self.dateKey(for: date)
                                CalendarDayCell(
                                    date: date,
                                    entry: vm.entries[dateKey],
                                    weather: vm.monthlyWeather[dateKey],
                                    postCount: vm.postsByDate[dateKey]?.count ?? 0,
                                    isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                    isToday: Calendar.current.isDateInToday(date),
                                    weekdayColumn: col
                                )
                                .onTapGesture {
                                    selectedDate = date
                                }
                            } else {
                                Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                            }

                            // Vertical grid line (except for last column)
                            if col < 6 {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 0.5)
                            }
                        }
                    }

                    // Horizontal grid line (except for last row)
                    if row < rows - 1 {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }

    // MARK: - Selected day panel
    @ViewBuilder
    private func selectedDayPanel(date: Date) -> some View {
        Group {
            let key = Self.dateKey(for: date)
            let _ = print("[DEBUG] selectedDayPanel: date=\(date), key=\(key)")
            let _ = print("[DEBUG] entries keys: \(vm.entries.keys.sorted())")
            let _ = print("[DEBUG] postsByDate keys: \(vm.postsByDate.keys.sorted())")
            let entry = vm.entries[key]
            let postsForDate = vm.postsByDate[key]
            let entryStatus = (entry != nil) ? "exists" : "nil"
            let _ = print("[DEBUG] entry: \(entryStatus), posts: \(postsForDate?.count ?? 0)")
            let isEditable = vm.canEdit(date, isSubscribed: isSubscribed)
            let isFuture = date > Date()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedDayTitle(date: date))
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if isFuture {
                    Text("未来の日付は記録できません")
                        .font(.system(size: 13))
                        .foregroundColor(Color(.systemGray))
                        .padding(.horizontal, 16)
                } else if !isEditable {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                        Text(isSubscribed ? "編集期間外です（2日以上前）" : "サブスクに登録すると2日前まで編集できます")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, 16)
                }

                // === 日記セクション ===
                if let entry = entry {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.closed")
                                .font(.system(size: 14))
                            Text("日記")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                            if isEditable {
                                Button {
                                    showEntrySheet = true
                                } label: {
                                    Text("編集")
                                        .font(.system(size: 12))
                                        .foregroundColor(.accentRed)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)

                        // 日記カード（タップで詳細）
                        CalendarEntryCard(entry: entry, isEditable: false) {
                            // 日記詳細表示（あれば）
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }

                // 新規投稿ボタン（日記がない場合。投稿があっても日記がなければ書ける）
                if entry == nil && !isFuture && isEditable {
                    Button {
                        showNewPostSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "camera")
                            Text("この日を投稿する")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.accentRed)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                    }
                }

                // === 投稿セクション ===
                if let posts = vm.postsByDate[key], !posts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 14))
                            Text("投稿 (\(posts.count)件)")
                                .font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)

                        // 投稿カード一覧（縦に並べて表示）
                        VStack(spacing: 8) {
                            ForEach(posts, id: \.post_id) { post in
                                PostThumbnailCard(post: post)
                                    .onTapGesture {
                                        selectedPostForDetail = post
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }

            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Public toggle
    private var calendarPublicToggle: some View {
        Button {
            if !vm.calendarIsPublic {
                // 非公開 → 公開 に変更する時は確認
                showPublicConfirm = true
            } else {
                Task { await vm.saveCalendarPublicSetting(uid: uid, isPublic: false) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.calendarIsPublic ? "globe" : "lock.fill")
                    .font(.system(size: 13))
                Text(vm.calendarIsPublic ? "公開中" : "非公開")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(vm.calendarIsPublic ? .accentBlue : Color(.systemGray))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(vm.calendarIsPublic ? Color.accentBlue.opacity(0.1) : Color(.systemGray6))
            )
        }
    }

    // MARK: - Helpers
    private func selectedDayTitle(date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日（E）"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: date)
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: displayedMonth)
    }

    private func dateFor(day: Int) -> Date? {
        var comps = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        return Calendar.current.date(from: comps)
    }

    static func dateKey(for date: Date) -> String {
        CalendarViewModel.dateKeyFormatter.string(from: date)
    }
}

// MARK: - CalendarDayCell
struct CalendarDayCell: View {
    let date: Date
    let entry: CalendarEntry?
    let weather: WeatherResult?      // 月全体の天気データ
    let postCount: Int
    let isSelected: Bool
    let isToday: Bool
    let weekdayColumn: Int

    private var isFuture: Bool { date > Date() }
    private var hasContent: Bool { entry != nil || postCount > 0 }

    // 優先順位: 1. 月全体の天気データ 2. 日記エントリーの天気データ
    private var displayWeather: String? {
        weather?.weatherType ?? entry?.weather_type
    }
    private var displayTempMax: Double? {
        weather?.tempMax ?? entry?.temp_max
    }
    private var displayTempMin: Double? {
        weather?.tempMin ?? entry?.temp_min
    }
    
    // 天気に応じた背景色（タイムライン同様）
    private var weatherBackgroundColor: Color {
        guard let wt = displayWeather.flatMap({ WeatherType(rawValue: $0) }) else {
            return Color(.systemGray6)
        }
        switch wt {
        case .sunny:  return Color.orange.opacity(0.35)
        case .cloudy: return Color.gray.opacity(0.35)
        case .rainy:  return Color.blue.opacity(0.35)
        case .snowy:  return Color.cyan.opacity(0.35)
        }
    }

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
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayTextColor)
            }
            .frame(width: 32, height: 32)

            // 中段: 天気アイコン + 気温（横1列、黒記号、背景色付き）
            HStack(spacing: 4) {
                // 天気記号（黒いSF Symbols）
                if let wt = displayWeather.flatMap({ WeatherType(rawValue: $0) }) {
                    Image(systemName: wt.sfSymbol)
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                } else {
                    Text("-")
                        .font(.system(size: 10))
                        .foregroundColor(Color(.systemGray4))
                }

                // 気温
                if let max = displayTempMax, let min = displayTempMin {
                    Text("\(Int(max.rounded()))°/\(Int(min.rounded()))°")
                        .font(.system(size: 9))
                        .foregroundColor(Color(.systemGray2))
                } else {
                    Text("-")
                        .font(.system(size: 9))
                        .foregroundColor(Color(.systemGray4))
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(weatherBackgroundColor)
            .cornerRadius(4)

            // 下段: 投稿数バッジ（ある場合のみ）
            if postCount > 0 {
                Text("\(postCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 14, height: 14)
                    .background(Color.accentBlue)
                    .clipShape(Circle())
            } else {
                Color.clear.frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentRed.opacity(0.08))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
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

// MARK: - CalendarEntryCard
struct CalendarEntryCard: View {
    let entry: CalendarEntry
    let isEditable: Bool
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let w = entry.weather_type.flatMap({ WeatherType(rawValue: $0) }) {
                        HStack(spacing: 4) {
                            Text(w.emoji).font(.system(size: 16))
                            if let max = entry.temp_max, let min = entry.temp_min {
                                Text("\(Int(max.rounded()))° / \(Int(min.rounded()))°")
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(.systemGray))
                            }
                        }
                    }
                    if !entry.comment.isEmpty {
                        Text(entry.comment)
                            .font(.system(size: 14))
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

            if isEditable {
                HStack {
                    Spacer()
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentRed)
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - PostThumbnailCard
// カレンダー日付パネル内に表示する投稿サムネイル

struct PostThumbnailCard: View {
    let post: Post

    var body: some View {
        HStack(spacing: 12) {
            if let urlStr = post.image_url_front ?? post.image_url_back,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(Color(.systemGray3))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(post.description)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentRed)
                    Text("\(post.likes_count)")
                        .font(.system(size: 11))
                        .foregroundColor(Color(.systemGray))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}

// MARK: - CalendarNewPostBridge
// カレンダーから新規投稿する際に、投稿を非公開・指定日付付きで開くためのブリッジ
struct CalendarNewPostBridge: View {
    let date: Date
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var postsViewModel = PostsViewModel()
    @StateObject private var draftManager = DraftManager()

    var body: some View {
        NewPostView(calendarDate: date, defaultIsPublic: false)
            .environmentObject(postsViewModel)
            .environmentObject(authViewModel)
            .environmentObject(draftManager)
    }
}

