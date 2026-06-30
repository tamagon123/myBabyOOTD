// =============================================================================
// ファイル名: CalendarView.swift
// 役割: カレンダー画面（月次表示・日付タップ・日記閲覧・新規投稿）
// 説明:
//   月ごとのカレンダーグリッドを表示し、日付タップで日記・投稿を確認/作成できます。
//   iPad対応: 左65%にカレンダー、右35%に選択日の詳細パネルを横並び表示。
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
    @State private var selectedEntryForDetail: CalendarEntry? = nil  // 日記詳細表示用
    @State private var showSearchConfirm = false                     // 検索確認アラート表示フラグ
    @State private var confirmSearchDate: Date? = nil                // 確認中の検索日付
    @State private var showPurchaseItemSheet = false                 // 購入品登録画面表示フラグ

    private var uid: String { Auth.currentUID }
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }

    var body: some View {
        CalendarRootContent(
            displayedMonth: $displayedMonth,
            selectedDate: $selectedDate,
            showEntrySheet: $showEntrySheet,
            showNewPostSheet: $showNewPostSheet,
            showPublicConfirm: $showPublicConfirm,
            selectedPostForDetail: $selectedPostForDetail,
            selectedEntryForDetail: $selectedEntryForDetail,
            showSearchConfirm: $showSearchConfirm,
            confirmSearchDate: $confirmSearchDate,
            showPurchaseItemSheet: $showPurchaseItemSheet
        )
        .environmentObject(authViewModel)
        .environmentObject(vm)
        .environmentObject(postsViewModel)
        .sheet(isPresented: $showPurchaseItemSheet) {
            if let selectedDate = selectedDate {
                PurchaseItemRegistrationView(selectedDate: selectedDate)
            }
        }
    }

    // MARK: - Top status bar (region + public toggle)
    private var topStatusBar: some View {
        HStack {
            Button {
                vm.showRegionPicker = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.appFont(.regular, size: 13))
                    Text(regionName)
                        .font(.appFont(.regular, size: 14))
                    Image(systemName: "chevron.down")
                        .font(.appFont(.regular, size: 10))
                }
                .foregroundColor(Color(.systemGray))
            }
            .disabled(vm.isLoading)

            Spacer()

            calendarPublicToggle
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.ecruBackground)
    }

    // MARK: - Region picker sheet
    private var regionPickerSheet: some View {
        NavigationView {
            List {
                // プロフィール地域が設定されていれば最上部に表示
                if let profileCode = vm.profileRegionCode,
                   let profileName = vm.prefectureNames[profileCode] {
                    Section(header: Text("プロフィール設定").font(.appFont(.regular, size: 12))) {
                        Button {
                            Task {
                                await vm.changeRegion(to: profileCode, uid: uid, around: displayedMonth)
                            }
                        } label: {
                            HStack {
                                Text(profileName)
                                    .font(.appFont(.medium, size: 16))
                                Spacer()
                                if profileCode == vm.selectedRegionCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentRed)
                                }
                                Text("設定中")
                                    .font(.appFont(.regular, size: 11))
                                    .foregroundColor(.accentRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentRed.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                // その他の地域リスト
                Section(header: Text("すべての地域").font(.appFont(.regular, size: 12))) {
                    ForEach(vm.sortedPrefectureCodes, id: \.self) { code in
                        Button {
                            Task {
                                await vm.changeRegion(to: code, uid: uid, around: displayedMonth)
                            }
                        } label: {
                            HStack {
                                Text(vm.prefectureNames[code] ?? "")
                                    .font(.appFont(.regular, size: 16))
                                Spacer()
                                if code == vm.selectedRegionCode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentRed)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .listStyle(.grouped)
            .navigationTitle("地域を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        vm.showRegionPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Month header (prev/next arrows)
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
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var regionName: String {
        vm.selectedRegionName
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

    // MARK: - Calendar grid with grid lines
    private var calendarGrid: some View {
        CalendarView.CalendarGrid(
            displayedMonth: displayedMonth,
            entries: vm.entries,
            monthlyWeather: vm.monthlyWeather,
            postsByDate: vm.postsByDate,
            selectedDate: $selectedDate
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
                        .font(.appFont(.bold, size: 16))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if isFuture {
                    Text("未来の日付は記録できません")
                        .font(.appFont(.regular, size: 13))
                        .foregroundColor(Color(.systemGray))
                        .padding(.horizontal, 16)
                } else if !isEditable {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.appFont(.regular, size: 12))
                        Text(isSubscribed ? "編集期間外です（365日以上前）" : "プレミアムプランを購入すると365日前まで編集できます")
                            .font(.appFont(.regular, size: 13))
                    }
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, 16)
                }

                // === 日記セクション ===
                if let entry = entry {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.closed")
                                .font(.appFont(.medium, size: 14))
                            Text("日記")
                                .font(.appFont(.regular, size: 14))
                            Spacer()
                            if isEditable {
                                Button {
                                    showEntrySheet = true
                                } label: {
                                    Text("編集")
                                        .font(.appFont(.regular, size: 12))
                                        .foregroundColor(.accentRed)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)

                        // 日記カード（タップで詳細）
                        CalendarEntryCard(
                            entry: entry,
                            isEditable: false,
                            onEdit: { showEntrySheet = true },
                            onTap: { selectedEntryForDetail = entry }
                        )
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
                                .font(.appFont(.regular, size: 12))
                        }
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.accentRed)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                    }
                }

                // === 投稿セクション（カレンダー投稿は除外） ===
                let regularPosts = vm.postsByDate[key]?.filter { !($0.is_calendar_post ?? false) } ?? []
                if !regularPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.appFont(.medium, size: 14))
                            Text("投稿 (\(regularPosts.count)件)")
                                .font(.appFont(.regular, size: 14))
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)

                        // 投稿カード一覧（縦に並べて表示）
                        VStack(spacing: 8) {
                            ForEach(regularPosts as [Post], id: \.post_id) { (post: Post) in
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

                // 購入品登録ボタン（過去日のみ）
                if let date = selectedDate, date <= Date() {
                    Button {
                        showPurchaseItemSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "bag")
                            Text("購入品を登録する")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.appFont(.regular, size: 12))
                        }
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.accentBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }

                // この日を検索するボタン（明日以降は非表示）
                if let date = selectedDate, !Calendar.current.isDateInTomorrow(date) && date <= Date() {
                    Button {
                        confirmSearchDate = date
                        showSearchConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("この日を検索する")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.appFont(.regular, size: 12))
                        }
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.accentRed)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .cornerRadius(12)
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
                    .font(.appFont(.medium, size: 13))
                Text(vm.calendarIsPublic ? "公開中" : "非公開")
                    .font(.appFont(.regular, size: 12))
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

    private func formatSearchDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: date)
    }
}

private struct CalendarRootContent: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel

    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date?
    @Binding var showEntrySheet: Bool
    @Binding var showNewPostSheet: Bool
    @Binding var showPublicConfirm: Bool
    @Binding var selectedPostForDetail: Post?
    @Binding var selectedEntryForDetail: CalendarEntry?
    @Binding var showSearchConfirm: Bool
    @Binding var confirmSearchDate: Date?
    @Binding var showPurchaseItemSheet: Bool

    private var uid: String { Auth.currentUID }
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        NavigationView {
            mainContent
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var mainContent: some View {
        Group {
            if isIPad {
                iPadTwoPaneContent
            } else {
                iPhoneContent
            }
        }
        .background(Color.ecruBackground.ignoresSafeArea())
        .navigationTitle("カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(loadingOverlay)
        .sheet(isPresented: $vm.showRegionPicker) { regionPickerSheet }
        .sheet(item: $selectedEntryForDetail) { entry in
            CalendarEntryDetailView(entry: entry) { deletedEntry in
                vm.entries.removeValue(forKey: deletedEntry.date_key)
            }
            .environmentObject(authViewModel)
        }
        .sheet(isPresented: $showEntrySheet, onDismiss: onDismissRefetch) {
            if let date = selectedDate {
                CalendarEntryEditView(date: date, vm: vm, uid: uid)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showNewPostSheet, onDismiss: onDismissRefetchNewPost) {
            if let date = selectedDate {
                CalendarNewPostBridge(date: date)
                    .environmentObject(authViewModel)
            }
        }
        .sheet(item: $selectedPostForDetail) { post in
            PostDetailView(
                post: post,
                postId: post.id ?? post.post_id
            )
                .environmentObject(authViewModel)
                .environmentObject(postsViewModel)
        }
        .modifier(CalendarAlertsModifier(
            vm: vm,
            postsViewModel: postsViewModel,
            showPublicConfirm: $showPublicConfirm,
            showSearchConfirm: $showSearchConfirm,
            confirmSearchDate: $confirmSearchDate,
            selectedRegionName: vm.selectedRegionName,
            uid: uid
        ))
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CalendarEntryUpdated"))) { _ in
            let currentUid = uid
            guard !currentUid.isEmpty else { return }
            Task {
                await vm.fetchEntries(uid: currentUid, around: displayedMonth)
                await vm.fetchPosts(uid: currentUid, around: displayedMonth)
            }
        }
        .task {
            let currentUid = uid
            guard !currentUid.isEmpty else { return }
            vm.setRegionFromProfile(authViewModel.currentUser?.region_code)
            await vm.fetchAllData(uid: currentUid, around: displayedMonth)
        }
        .onChange(of: displayedMonth) { month in
            let currentUid = uid
            guard !currentUid.isEmpty else { return }
            Task { await vm.fetchAllData(uid: currentUid, around: month) }
        }
    }

    // MARK: - iPhone: 縦スタック（従来レイアウト）
    private var iPhoneContent: some View {
        VStack(spacing: 0) {
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
    }

    // MARK: - iPad: 左ペイン（カレンダー 65%） + 右ペイン（選択日詳細 35%）
    // 説明: GeometryReaderで全幅を65:35に分割。カレンダーを広く、詳細をコンパクトに。
    private var iPadTwoPaneContent: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // 左ペイン: カレンダー本体 (65%)
                VStack(spacing: 0) {
                    topStatusBar
                    ScrollView {
                        VStack(spacing: 0) {
                            monthHeader
                            weekdayHeader
                            calendarGrid
                        }
                        .padding(.bottom, 16)
                    }
                }
                .frame(width: geo.size.width * 0.65)

                Divider()

                // 右ペイン: 選択日の詳細 (35%)
                Group {
                    if let date = selectedDate {
                        ScrollView {
                            selectedDayPanel(date: date)
                                .padding(.top, 8)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("日付を選択してください")
                                .font(.appFont(.regular, size: 15))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(width: geo.size.width * 0.35, alignment: .top)
                .background(Color(.systemBackground))
            }
        }
    }

    // MARK: - Extracted small helpers to reduce type-checking load
    private var loadingOverlay: some View {
        Group {
            if vm.isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("読み込み中...")
                            .font(.appFont(.medium, size: 14))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.7))
                    )
                }
            }
        }
    }

    private func onDismissRefetch() {
        let currentUid = uid
        guard !currentUid.isEmpty else { return }
        Task {
            await vm.fetchEntries(uid: currentUid, around: displayedMonth)
            await vm.fetchPosts(uid: currentUid, around: displayedMonth)
        }
    }

    private func onDismissRefetchNewPost() {
        let currentUid = uid
        guard !currentUid.isEmpty else { return }
        Task {
            await vm.fetchEntries(uid: currentUid, around: displayedMonth)
            await vm.fetchPosts(uid: currentUid, around: displayedMonth)
        }
    }

    // MARK: - Reuse existing subviews and helpers from CalendarView through forwarding
    private var topStatusBar: some View { 
        CalendarView.TopStatusBar(
            regionName: vm.selectedRegionName, 
            calendarPublicToggle: calendarPublicToggle, 
            isLoading: vm.isLoading
        ) { 
            vm.showRegionPicker = true 
        } 
    }

    private var regionPickerSheet: some View { 
        CalendarViewRegionPicker(vm: vm, uid: uid, displayedMonth: displayedMonth) 
    }

    private var monthHeader: some View { 
        CalendarView.MonthHeader(displayedMonth: $displayedMonth) 
    }

    private var weekdayHeader: some View { 
        CalendarView.WeekdayHeader() 
    }

    private var calendarGrid: some View {
        CalendarView.CalendarGrid(
            displayedMonth: displayedMonth,
            entries: vm.entries,
            monthlyWeather: vm.monthlyWeather,
            postsByDate: vm.postsByDate,
            selectedDate: $selectedDate
        )
    }

    @ViewBuilder
    private func selectedDayPanel(date: Date) -> some View {
        CalendarViewSelectedDayPanel(
            date: date,
            isSubscribed: isSubscribed,
            selectedDate: $selectedDate,
            showEntrySheet: $showEntrySheet,
            showNewPostSheet: $showNewPostSheet,
            selectedPostForDetail: $selectedPostForDetail,
            selectedEntryForDetail: $selectedEntryForDetail,
            showSearchConfirm: $showSearchConfirm,
            confirmSearchDate: $confirmSearchDate,
            vm: vm,
            postsViewModel: postsViewModel
        )
    }

    private var calendarPublicToggle: some View {
        Button {
            if !vm.calendarIsPublic {
                showPublicConfirm = true
            } else {
                Task { await vm.saveCalendarPublicSetting(uid: uid, isPublic: false) }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: vm.calendarIsPublic ? "globe" : "lock.fill")
                    .font(.appFont(.medium, size: 13))
                Text(vm.calendarIsPublic ? "公開中" : "非公開")
                    .font(.appFont(.regular, size: 12))
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
}

// MARK: - CalendarAlertsModifier
// アラートを分離して型チェック負荷を軽減
private struct CalendarAlertsModifier: ViewModifier {
    @ObservedObject var vm: CalendarViewModel
    @ObservedObject var postsViewModel: PostsViewModel
    @Binding var showPublicConfirm: Bool
    @Binding var showSearchConfirm: Bool
    @Binding var confirmSearchDate: Date?
    let selectedRegionName: String
    let uid: String

    func body(content: Content) -> some View {
        content
            .alert("カレンダーを公開しますか？", isPresented: $showPublicConfirm) {
                Button("公開する", role: .none) {
                    Task { await vm.saveCalendarPublicSetting(uid: uid, isPublic: true) }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("カレンダーの日記内容が他のユーザーに公開されます。")
            }
            .alert("この日を検索しますか？", isPresented: $showSearchConfirm, presenting: confirmSearchDate) { date in
                Button("検索する", role: .none) {
                    Task {
                        await postsViewModel.searchByDateAndRegion(date: date, regionCode: vm.selectedRegionCode)
                        NotificationCenter.default.post(name: Notification.Name("SwitchToTab"), object: nil, userInfo: ["tab": 0])
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: { date in
                Text("\(selectedRegionName)・\(formatSearchDate(date))の投稿を検索します")
            }
    }

    private func formatSearchDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "M月d日"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: date)
    }
}

extension CalendarView {
    struct TopStatusBar: View {
        let regionName: String
        let calendarPublicToggle: AnyView
        let isLoading: Bool
        let onTapRegion: () -> Void
        init(regionName: String, calendarPublicToggle: some View, isLoading: Bool, onTapRegion: @escaping () -> Void) {
            self.regionName = regionName
            self.calendarPublicToggle = AnyView(calendarPublicToggle)
            self.isLoading = isLoading
            self.onTapRegion = onTapRegion
        }
        var body: some View {
            HStack {
                Button(action: onTapRegion) {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse").font(.appFont(.regular, size: 13))
                        Text(regionName).font(.appFont(.regular, size: 14))
                        Image(systemName: "chevron.down").font(.appFont(.regular, size: 10))
                    }
                    .foregroundColor(Color(.systemGray))
                }
                .disabled(isLoading)
                Spacer()
                calendarPublicToggle
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.ecruBackground)
        }
    }

    struct MonthHeader: View {
        @Binding var displayedMonth: Date
        var body: some View {
            HStack {
                Button { displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth } label: {
                    Image(systemName: "chevron.left").font(.appFont(.medium, size: 18)).foregroundColor(.accentRed).padding(10)
                }
                Spacer()
                Text(monthTitle).font(.appFont(.bold, size: 18)).foregroundColor(.primary)
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
                .disabled({ let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth; return next > Date() }())
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
        private var monthTitle: String {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy年M月"; fmt.locale = Locale(identifier: "ja_JP"); return fmt.string(from: displayedMonth)
        }
    }

    struct WeekdayHeader: View { var body: some View {
        let labels = ["日","月","火","水","木","金","土"]
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
    } }

    struct CalendarGrid: View {
        let displayedMonth: Date
        let entries: [String: CalendarEntry]
        let monthlyWeather: [String: WeatherResult]
        let postsByDate: [String: [Post]]
        @Binding var selectedDate: Date?
        var body: some View {
            let cal = Calendar.current
            let firstWeekday = cal.firstWeekdayOfMonth(for: displayedMonth)
            let offset = (firstWeekday - 1 + 7) % 7
            let totalDays = cal.daysInMonth(for: displayedMonth)
            let cells = offset + totalDays
            let rows = Int(ceil(Double(cells) / 7.0))
            return VStack(spacing: 0) {
                ForEach(Array(0..<rows), id: \.self) { row in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            ForEach(Array(0..<7), id: \.self) { col in
                                let cellIndex = row * 7 + col
                                let dayNum = cellIndex - offset + 1
                                if dayNum >= 1 && dayNum <= totalDays, let date = dateFor(day: dayNum) {
                                    let dateKey = CalendarView.dateKey(for: date)
                                    CalendarDayCell(
                                        date: date,
                                        entry: entries[dateKey],
                                        weather: monthlyWeather[dateKey],
                                        postCount: postsByDate[dateKey]?.count ?? 0,
                                        isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                        isToday: Calendar.current.isDateInToday(date),
                                        weekdayColumn: col
                                    )
                                    .onTapGesture { selectedDate = date }
                                } else {
                                    Color.clear.frame(maxWidth: .infinity, minHeight: 56)
                                }
                                if col < 6 { Rectangle().fill(Color(.systemGray3)).frame(width: 0.5) }
                            }
                        }
                        if row < rows - 1 { Rectangle().fill(Color(.systemGray3)).frame(height: 0.5) }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        private func dateFor(day: Int) -> Date? {
            var comps = Calendar.current.dateComponents([.year, .month], from: displayedMonth)
            comps.day = day
            return Calendar.current.date(from: comps)
        }
    }
}

private struct CalendarViewRegionPicker: View {
    @ObservedObject var vm: CalendarViewModel
    let uid: String
    let displayedMonth: Date
    var body: some View {
        NavigationView {
            List {
                if let profileCode = vm.profileRegionCode, let profileName = vm.prefectureNames[profileCode] {
                    Section(header: Text("プロフィール設定").font(.appFont(.regular, size: 12))) {
                        Button { Task { await vm.changeRegion(to: profileCode, uid: uid, around: displayedMonth) } } label: {
                            HStack {
                                Text(profileName).font(.appFont(.medium, size: 16))
                                Spacer()
                                if profileCode == vm.selectedRegionCode { Image(systemName: "checkmark").foregroundColor(.accentRed) }
                                Text("設定中")
                                    .font(.appFont(.regular, size: 11))
                                    .foregroundColor(.accentRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentRed.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                Section(header: Text("すべての地域").font(.appFont(.regular, size: 12))) {
                    ForEach(vm.sortedPrefectureCodes, id: \.self) { code in
                        Button { Task { await vm.changeRegion(to: code, uid: uid, around: displayedMonth) } } label: {
                            HStack {
                                Text(vm.prefectureNames[code] ?? "").font(.appFont(.regular, size: 16))
                                Spacer()
                                if code == vm.selectedRegionCode { Image(systemName: "checkmark").foregroundColor(.accentRed) }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .listStyle(.grouped)
            .navigationTitle("地域を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("閉じる") { vm.showRegionPicker = false } } }
        }
    }
}

private struct CalendarViewSelectedDayPanel: View {
    let date: Date
    let isSubscribed: Bool
    @Binding var selectedDate: Date?
    @Binding var showEntrySheet: Bool
    @Binding var showNewPostSheet: Bool
    @Binding var selectedPostForDetail: Post?
    @Binding var selectedEntryForDetail: CalendarEntry?
    @Binding var showSearchConfirm: Bool
    @Binding var confirmSearchDate: Date?
    @ObservedObject var vm: CalendarViewModel
    @ObservedObject var postsViewModel: PostsViewModel

    var body: some View {
        Group {
            let key = CalendarView.dateKey(for: date)
            let entry = vm.entries[key]
            let isEditable = vm.canEdit(date, isSubscribed: isSubscribed)
            let isFuture = date > Date()
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text(selectedDayTitle(date: date)).font(.appFont(.bold, size: 16)); Spacer() }
                    .padding(.horizontal, 16).padding(.top, 16)
                if isFuture {
                    Text("未来の日付は記録できません").font(.appFont(.regular, size: 13)).foregroundColor(Color(.systemGray)).padding(.horizontal, 16)
                } else if !isEditable {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill").font(.appFont(.regular, size: 12))
                        Text(isSubscribed ? "編集期間外です（365日以上前）" : "プレミアムプランを購入すると365日前まで編集できます").font(.appFont(.regular, size: 13))
                    }
                    .foregroundColor(Color(.systemGray)).padding(.horizontal, 16)
                }
                if let entry = entry {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "book.closed").font(.appFont(.medium, size: 14))
                            Text("日記").font(.appFont(.regular, size: 14))
                            Spacer()
                            if isEditable { Button { showEntrySheet = true } label: { Text("編集").font(.appFont(.regular, size: 12)).foregroundColor(.accentRed) } }
                        }
                        .foregroundColor(.primary).padding(.horizontal, 16)
                        CalendarEntryCard(entry: entry, isEditable: false, onEdit: { showEntrySheet = true }, onTap: { selectedEntryForDetail = entry }).padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }
                if entry == nil && !isFuture && isEditable {
                    Button { showNewPostSheet = true } label: {
                        HStack { Image(systemName: "camera"); Text("この日を投稿する"); Spacer(); Image(systemName: "chevron.right").font(.appFont(.regular, size: 12)) }
                            .font(.appFont(.regular, size: 14))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 12)
                    }
                }
                let regularPosts = vm.postsByDate[key]?.filter { !($0.is_calendar_post ?? false) } ?? []
                if !regularPosts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.on.rectangle").font(.appFont(.medium, size: 14))
                            Text("投稿 (\(regularPosts.count)件)").font(.appFont(.regular, size: 14))
                            Spacer()
                        }
                        .foregroundColor(.primary).padding(.horizontal, 16)
                        VStack(spacing: 8) {
                            ForEach(regularPosts as [Post], id: \.post_id) { (post: Post) in
                                PostThumbnailCard(post: post).onTapGesture { selectedPostForDetail = post }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }
                if let date = selectedDate {
                    Button {
                        confirmSearchDate = date
                        showSearchConfirm = true
                    } label: {
                        HStack { Image(systemName: "magnifyingglass"); Text("この日を検索する"); Spacer(); Image(systemName: "chevron.right").font(.appFont(.regular, size: 12)) }
                            .font(.appFont(.regular, size: 14))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func selectedDayTitle(date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M月d日（E）"; fmt.locale = Locale(identifier: "ja_JP"); return fmt.string(from: date)
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
    
    // 天気に応じた背景色（薄く）
    private var weatherBackgroundColor: Color {
        guard let wt = displayWeather.flatMap({ WeatherType(rawValue: $0) }) else {
            return Color(.systemGray6)
        }
        switch wt {
        case .sunny:  return Color.orange.opacity(0.2)
        case .cloudy: return Color.gray.opacity(0.2)
        case .rainy:  return Color.blue.opacity(0.2)
        case .snowy:  return Color.cyan.opacity(0.2)
        }
    }
    
    // 日記または投稿があるかどうか
    private var hasDiaryOrPost: Bool { entry != nil || postCount > 0 }

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
            .background(
                // 投稿がある日は薄い黄色の丸い背景
                hasDiaryOrPost && !isSelected ? Circle().fill(Color.yellow.opacity(0.3)) : nil
            )

            // 天気気温セクション：記号左・気温右（横並び）
            HStack(spacing: 4) {
                // 左：天気記号
                if let wt = displayWeather.flatMap({ WeatherType(rawValue: $0) }) {
                    Image(systemName: wt.sfSymbol)
                        .font(.appFont(.regular, size: 10))
                        .foregroundColor(Color.black.opacity(0.9))
                } else {
                    Text("-")
                        .font(.appFont(.regular, size: 10))
                        .foregroundColor(Color(.systemGray4))
                }
                
                // 右：気温（分数形式）
                if let max = displayTempMax, let min = displayTempMin {
                    VStack(spacing: 0) {
                        Text("\(Int(max.rounded()))°")
                            .font(.appFont(.medium, size: 8))
                            .foregroundColor(Color.black.opacity(0.8))
                        // 横棒（分数の線）
                        Rectangle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 14, height: 0.5)
                            .padding(.vertical, 0.5)
                        Text("\(Int(min.rounded()))°")
                            .font(.appFont(.medium, size: 8))
                            .foregroundColor(Color.black.opacity(0.8))
                    }
                } else {
                    Text("-")
                        .font(.appFont(.regular, size: 9))
                        .foregroundColor(Color(.systemGray4))
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 1)
            .background(weatherBackgroundColor)
            .cornerRadius(3)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .opacity(isFuture ? 0.3 : 1.0)
    }

    private var dayTextColor: Color {
        if isSelected { return .white }
        if isFuture { return Color(.systemGray2) }
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
    var onTap: (() -> Void)?  // タップで詳細表示
    
    init(entry: CalendarEntry, isEditable: Bool, onEdit: @escaping () -> Void, onTap: (() -> Void)? = nil) {
        self.entry = entry
        self.isEditable = isEditable
        self.onEdit = onEdit
        self.onTap = onTap
    }

    var body: some View {
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

            HStack {
                // タップして詳細表示ボタン
                if onTap != nil {
                    Button(action: { onTap?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.text")
                            Text("詳細")
                        }
                        .font(.appFont(.medium, size: 13))
                        .foregroundColor(.accentBlue)
                    }
                }
                Spacer()
                if isEditable {
                    Button(action: onEdit) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("編集")
                        }
                        .font(.appFont(.medium, size: 13))
                        .foregroundColor(.accentRed)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
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
                    .font(.appFont(.regular, size: 13))
                    .lineLimit(2)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.appFont(.regular, size: 10))
                        .foregroundColor(.accentRed)
                    Text("\(post.likes_count)")
                        .font(.appFont(.regular, size: 11))
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
        NewPostView(calendarDate: date)
            .environmentObject(postsViewModel)
            .environmentObject(authViewModel)
            .environmentObject(draftManager)
    }
}


