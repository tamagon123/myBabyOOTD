// =============================================================================
// ファイル名: SearchView.swift
// 役割: 検索画面（地域・性別・天気・気温・ブランド・サイズでの絞り込み検索）
// 説明:
//   検索タブから遷移する検索画面です。
//   地域、子供の性別、天気、気温帯、ブランド名、アイテムサイズなどの条件を
//   組み合わせて投稿を絞り込み検索できます。
//   検索結果はタイムラインと同じPostCardViewで一覧表示されます。
// =============================================================================

import SwiftUI
import FirebaseFirestore

struct SearchView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var postsViewModel: PostsViewModel
    @Environment(\.dismiss) private var dismiss

    // === 検索条件 ===
    @State private var selectedRegionIndices: Set<Int> = []    // 選択された都道府県
    @State private var tempRegionIndex: Int = -1               // Picker一時選択値
    @State private var selectedGenders: Set<Int> = []        // 選択された性別
    @State private var selectedWeathers: Set<String> = []      // 選択された天気
    @State private var selectedTempMaxCategories: Set<String> = []  // 選択された最高気温
    @State private var selectedTempMinCategories: Set<String> = []    // 選択された最低気温
    @State private var selectedBrandNames: Set<String> = []    // 選択されたブランド
    @State private var freeBrandQuery: String = ""             // ブランド自由入力
    @State private var sheetSelectedBrand: String = ""        // シート選択一時値
    @State private var showBrandSearch = false                // ブランド検索シート表示フラグ
    @State private var selectedSizeIndices: Set<Int> = []     // 選択されたサイズ
    @State private var selectedFilter: PostFilterType = .postsOnly  // 投稿フィルター（投稿のみ/日記のみ/両方）
    @State private var startDate: Date? = nil                  // 検索開始日
    @State private var endDate: Date? = nil                    // 検索終了日
    @State private var showStartDatePicker = false             // 開始日Picker表示フラグ
    @State private var showEndDatePicker = false               // 終了日Picker表示フラグ

    // === 検索結果 ===
    @State private var results: [Post] = []        // 検索結果の投稿リスト
    @State private var isLoading = false           // 検索実行中フラグ
    @State private var errorMessage: String? = nil  // エラーメッセージ

    // === プライベート ===
    private let db = Firestore.firestore()

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 検索画面の全体レイアウトを定義
    // 構成:
    //   1. AppHeaderView（検索アイコン非表示）
    //   2. ScrollView内に:
    //      - filterSection: 検索条件入力UI（Picker, TextField等）
    //      - searchButton: 検索実行ボタン
    //      - 検索結果表示（PostCardViewのリスト）
    // =============================================================================
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeaderView(showSearchButton: false)

                ScrollView {

                    VStack(alignment: .leading, spacing: 20) {
                        filterSection
                        searchButton

                        if let err = errorMessage {
                            Text(err)
                                .foregroundColor(.red)
                                .font(.appFont(.regular, size: 13))
                                .padding()
                        } else if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding()
                        } else if results.isEmpty {
                            EmptyView()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(results, id: \.post_id) { post in
                                    PostCardView(
                                        post: post,
                                        isLiked: false,
                                        onLike: {},
                                        onReport: {}
                                    )
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showBrandSearch, onDismiss: {
                if !sheetSelectedBrand.isEmpty && !selectedBrandNames.contains(sheetSelectedBrand) {
                    selectedBrandNames.insert(sheetSelectedBrand)
                }
                sheetSelectedBrand = ""
            }) {
                BrandSearchSheet(selectedBrand: $sheetSelectedBrand)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Filter UI
    // 説明: 検索条件入力用の各種Picker・TextFieldをまとめたView

    // =============================================================================
    // 【Viewサマリー】filterSection
    // 目的: 地域・性別・天気・気温・ブランド・サイズの検索条件UIをまとめて表示する
    // 戻り値: some View
    // =============================================================================
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("絞り込み検索")
                .font(.appFont(.bold, size: 17))
                .padding(.horizontal)

            // Region
            filterRow(label: "地域") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("地域", selection: $tempRegionIndex) {
                        Text("都道府県を追加").tag(-1)
                        ForEach(prefectures.indices, id: \.self) { i in
                            Text(prefectures[i]).tag(i)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: tempRegionIndex) { newValue in
                        if newValue >= 0 {
                            selectedRegionIndices.insert(newValue)
                            tempRegionIndex = -1
                        }
                    }
                    if !selectedRegionIndices.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(selectedRegionIndices).sorted(), id: \.self) { idx in
                                    HStack(spacing: 4) {
                                        Text(prefectures[idx])
                                            .font(.appFont(.regular, size: 12))
                                        Button {
                                            selectedRegionIndices.remove(idx)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.appFont(.regular, size: 12))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentRed.opacity(0.15))
                                    .foregroundColor(.accentRed)
                                    .cornerRadius(14)
                                }
                            }
                        }
                    }
                }
            }

            // Gender
            filterRow(label: "性別") {
                HStack(spacing: 6) {
                    ForEach(ChildGender.allCases) { g in
                        chipButton(label: g.label, active: selectedGenders.contains(g.rawValue)) {
                            if selectedGenders.contains(g.rawValue) {
                                selectedGenders.remove(g.rawValue)
                            } else {
                                selectedGenders.insert(g.rawValue)
                            }
                        }
                    }
                }
            }

            // Weather
            filterRow(label: "天気") {
                HStack(spacing: 6) {
                    chipButton(label: "すべて", active: selectedWeathers.isEmpty) {
                        selectedWeathers.removeAll()
                    }
                    ForEach(WeatherType.allCases) { w in
                        Button {
                            if selectedWeathers.contains(w.rawValue) {
                                selectedWeathers.remove(w.rawValue)
                            } else {
                                selectedWeathers.insert(w.rawValue)
                            }
                        } label: {
                            Label(w.label, systemImage: w.sfSymbol)
                                .font(.appFont(.medium, size: 12))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedWeathers.contains(w.rawValue) ? Color.accentRed : Color(.systemGray6))
                                .foregroundColor(selectedWeathers.contains(w.rawValue) ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
            }

            // 最高気温
            filterRow(label: "最高気温") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipButton(label: "すべて", active: selectedTempMaxCategories.isEmpty) {
                            selectedTempMaxCategories.removeAll()
                        }
                        ForEach(tempCategories, id: \.key) { cat in
                            chipButton(label: cat.label, active: selectedTempMaxCategories.contains(cat.key)) {
                                if selectedTempMaxCategories.contains(cat.key) {
                                    selectedTempMaxCategories.remove(cat.key)
                                } else {
                                    selectedTempMaxCategories.insert(cat.key)
                                }
                            }
                        }
                    }
                }
            }

            // 最低気温
            filterRow(label: "最低気温") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipButton(label: "すべて", active: selectedTempMinCategories.isEmpty) {
                            selectedTempMinCategories.removeAll()
                        }
                        ForEach(tempCategories, id: \.key) { cat in
                            chipButton(label: cat.label, active: selectedTempMinCategories.contains(cat.key)) {
                                if selectedTempMinCategories.contains(cat.key) {
                                    selectedTempMinCategories.remove(cat.key)
                                } else {
                                    selectedTempMinCategories.insert(cat.key)
                                }
                            }
                        }
                    }
                }
            }

            // Brand
            filterRow(label: "ブランド") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("ブランド名を入力", text: $freeBrandQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                let trimmed = freeBrandQuery.trimmingCharacters(in: .whitespaces)
                                if !trimmed.isEmpty {
                                    selectedBrandNames.insert(trimmed)
                                    freeBrandQuery = ""
                                }
                            }
                        Button {
                            showBrandSearch = true
                        } label: {
                            Text("検索")
                                .font(.appFont(.medium, size: 13))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentRed)
                                .cornerRadius(8)
                        }
                    }
                    if !selectedBrandNames.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(selectedBrandNames), id: \.self) { name in
                                    HStack(spacing: 4) {
                                        Text(name)
                                            .font(.appFont(.regular, size: 12))
                                        Button {
                                            selectedBrandNames.remove(name)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.appFont(.regular, size: 12))
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentRed.opacity(0.15))
                                    .foregroundColor(.accentRed)
                                    .cornerRadius(14)
                                }
                            }
                        }
                    }
                }
            }

            // Size
            filterRow(label: "サイズ") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(clothingSizes.indices, id: \.self) { i in
                            chipButton(label: sizeLabel(clothingSizes[i]), active: selectedSizeIndices.contains(i)) {
                                if selectedSizeIndices.contains(i) {
                                    selectedSizeIndices.remove(i)
                                } else {
                                    selectedSizeIndices.insert(i)
                                }
                            }
                        }
                    }
                }
            }

            // 日付フィルター
            filterRow(label: "日付") {
                VStack(alignment: .leading, spacing: 8) {
                    // 開始日
                    Button {
                        showStartDatePicker.toggle()
                        showEndDatePicker = false
                    } label: {
                        HStack {
                            Text(startDate != nil ? formatDate(startDate!) : "開始日を選択")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(startDate != nil ? .primary : Color(.systemGray))
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(.accentRed)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if showStartDatePicker {
                        DatePicker("", selection: Binding(
                            get: { startDate ?? Date() },
                            set: { startDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }

                    // 終了日
                    Button {
                        showEndDatePicker.toggle()
                        showStartDatePicker = false
                    } label: {
                        HStack {
                            Text(endDate != nil ? formatDate(endDate!) : "終了日を選択")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(endDate != nil ? .primary : Color(.systemGray))
                            Spacer()
                            Image(systemName: "calendar")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(.accentRed)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    if showEndDatePicker {
                        DatePicker("", selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                    }

                    // クリアボタン
                    if startDate != nil || endDate != nil {
                        Button {
                            startDate = nil
                            endDate = nil
                            showStartDatePicker = false
                            showEndDatePicker = false
                        } label: {
                            Text("日付をクリア")
                                .font(.appFont(.regular, size: 12))
                                .foregroundColor(.accentRed)
                        }
                    }
                }
            }

            // 投稿タイプフィルター
            filterRow(label: "表示タイプ") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(PostFilterType.allCases) { filter in
                            chipButton(label: filter.rawValue, active: selectedFilter == filter) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
            }
        }
    }

    private var searchButton: some View {
        Button {
            Task { await executeSearch() }
        } label: {
            Label("検索する", systemImage: "magnifyingglass")
                .font(.appFont(.bold, size: 15))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentRed)
                .cornerRadius(14)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func filterRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            content()
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func chipButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.appFont(.medium, size: 12))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? Color.accentRed : Color(.systemGray6))
                .foregroundColor(active ? .white : .primary)
                .cornerRadius(16)
        }
    }

    // MARK: - Helpers

    /// 気温帯キー（"0-9", "10-14", "15-19", "20-24", "25-"）と気温値を照合
    private func tempMatches(_ temp: Double, category: String) -> Bool {
        switch category {
        case "0-9":   return temp >= 0 && temp <= 9
        case "10-14": return temp >= 10 && temp <= 14
        case "15-19": return temp >= 15 && temp <= 19
        case "20-24": return temp >= 20 && temp <= 24
        case "25-":   return temp >= 25
        default:      return false
        }
    }

    // MARK: - Search

    private func executeSearch() async {
        isLoading = true
        do {
            // Firestoreから非表示でない投稿を新着順に取得（複合インデックス不要）
            let query: Query = db.collection("posts")
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .limit(to: 50)

            let snapshot = try await query.getDocuments()
            var fetched = try snapshot.documents.map { try $0.data(as: Post.self) }

            // クライアント側で各種条件をフィルタリング（複合インデックス不要）
            if !selectedRegionIndices.isEmpty {
                fetched = fetched.filter { post in
                    selectedRegionIndices.contains { idx in
                        String(format: "%02d", idx + 1) == post.region_code
                    }
                }
            }
            if !selectedGenders.isEmpty {
                fetched = fetched.filter { selectedGenders.contains($0.gender_id) }
            }
            if !selectedWeathers.isEmpty {
                fetched = fetched.filter { selectedWeathers.contains($0.weather_type) }
            }
            if !selectedTempMaxCategories.isEmpty {
                fetched = fetched.filter { post in
                    selectedTempMaxCategories.contains { tempMatches(post.temp_max, category: $0) }
                }
            }
            if !selectedTempMinCategories.isEmpty {
                fetched = fetched.filter { post in
                    selectedTempMinCategories.contains { tempMatches(post.temp_min, category: $0) }
                }
            }

            // ブランド検索：説明文またはアイテムのcustom_nameにマッチ（複数ブランド OR）
            let allBrandQueries = selectedBrandNames.union(freeBrandQuery.isEmpty ? [] : [freeBrandQuery])
            if !allBrandQueries.isEmpty {
                let brandLowers = allBrandQueries.map { $0.lowercased() }
                var matchedIds = Set(fetched
                    .filter { post in brandLowers.contains(where: { post.description.lowercased().contains($0) }) }
                    .map { $0.post_id })
                let postsNeedingCheck = fetched.filter { !matchedIds.contains($0.post_id) }
                if !postsNeedingCheck.isEmpty {
                    for post in postsNeedingCheck {
                        let postId = post.id ?? post.post_id
                        if let itemsSnap = try? await db.collection("posts").document(postId)
                            .collection("items").getDocuments() {
                            let itemNames = itemsSnap.documents.compactMap { $0.data()["custom_name"] as? String }
                            let itemNamesLower = itemNames.map { $0.lowercased() }
                            if brandLowers.contains(where: { brand in
                                itemNamesLower.contains(where: { $0.contains(brand) })
                            }) {
                                matchedIds.insert(post.post_id)
                            }
                        }
                    }
                }
                fetched = fetched.filter { matchedIds.contains($0.post_id) }
            }

            // 日付フィルター適用
            if let start = startDate {
                let cal = Calendar.current
                let startOfDay = cal.startOfDay(for: start)
                fetched = fetched.filter { post in
                    post.created_at.dateValue() >= startOfDay
                }
            }
            if let end = endDate {
                let cal = Calendar.current
                let endOfDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: end)) ?? end
                fetched = fetched.filter { post in
                    post.created_at.dateValue() < endOfDay
                }
            }

            // 投稿タイプフィルター適用（投稿のみ/日記のみ/両方）
            switch selectedFilter {
            case .postsOnly:
                fetched = fetched.filter { !($0.is_calendar_post ?? false) }
            case .diaryOnly:
                fetched = fetched.filter { $0.is_calendar_post ?? false }
            case .all:
                break // 全て表示
            }

            results = fetched
            errorMessage = nil

            // タイムラインに検索結果を反映して戻る
            postsViewModel.searchResults = fetched
            postsViewModel.isSearchActive = true
            dismiss()
        } catch {
            errorMessage = "検索中にエラーが発生しました。再度お試しください。"
        }
        isLoading = false
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy年M月d日"
        fmt.locale = Locale(identifier: "ja_JP")
        return fmt.string(from: date)
    }
}
