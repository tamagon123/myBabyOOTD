import SwiftUI
import FirebaseFirestore

struct SearchView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var selectedRegionIndex: Int = -1    // -1 = 全国
    @State private var selectedGender: ChildGender = .unselected
    @State private var selectedWeather: WeatherType? = nil
    @State private var selectedMaxTempCategory: String = ""
    @State private var selectedMinTempCategory: String = ""
    @State private var brandQuery: String = ""
    @State private var selectedSizeIndex: Int = -1      // -1 = 全サイズ

    @State private var results: [Post] = []
    @State private var isLoading = false

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeaderView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        filterSection
                        searchButton

                        if isLoading {
                            HStack { Spacer(); ProgressView(); Spacer() }
                                .padding()
                        } else if results.isEmpty {
                            EmptyView()
                        } else {
                            LazyVStack(spacing: 0) {
                                ForEach(results) { post in
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
        }
    }

    // MARK: - Filter UI

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("絞り込み検索")
                .font(.system(size: 17, weight: .bold))
                .padding(.horizontal)

            // Region
            filterRow(label: "地域") {
                Picker("地域", selection: $selectedRegionIndex) {
                    Text("全国").tag(-1)
                    ForEach(prefectures.indices, id: \.self) { i in
                        Text(prefectures[i]).tag(i)
                    }
                }
                .pickerStyle(.menu)
            }

            // Gender
            filterRow(label: "性別") {
                HStack(spacing: 6) {
                    ForEach(ChildGender.allCases) { g in
                        chipButton(label: g.label, active: selectedGender == g) {
                            selectedGender = (selectedGender == g) ? .unselected : g
                        }
                    }
                }
            }

            // Weather
            filterRow(label: "天気") {
                HStack(spacing: 6) {
                    chipButton(label: "すべて", active: selectedWeather == nil) {
                        selectedWeather = nil
                    }
                    ForEach(WeatherType.allCases) { w in
                        chipButton(label: w.emoji + w.label, active: selectedWeather == w) {
                            selectedWeather = (selectedWeather == w) ? nil : w
                        }
                    }
                }
            }

            // Max Temp Category
            filterRow(label: "最高気温帯") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipButton(label: "すべて", active: selectedMaxTempCategory.isEmpty) {
                            selectedMaxTempCategory = ""
                        }
                        ForEach(tempCategories, id: \.key) { cat in
                            chipButton(label: cat.label, active: selectedMaxTempCategory == cat.key) {
                                selectedMaxTempCategory = (selectedMaxTempCategory == cat.key) ? "" : cat.key
                            }
                        }
                    }
                }
            }

            // Min Temp Category
            filterRow(label: "最低気温帯") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chipButton(label: "すべて", active: selectedMinTempCategory.isEmpty) {
                            selectedMinTempCategory = ""
                        }
                        ForEach(tempCategories, id: \.key) { cat in
                            chipButton(label: cat.label, active: selectedMinTempCategory == cat.key) {
                                selectedMinTempCategory = (selectedMinTempCategory == cat.key) ? "" : cat.key
                            }
                        }
                    }
                }
            }

            // Brand
            filterRow(label: "ブランド") {
                TextField("例：UNIQLO", text: $brandQuery)
                    .textFieldStyle(.roundedBorder)
            }

            // Size
            filterRow(label: "サイズ") {
                Picker("サイズ", selection: $selectedSizeIndex) {
                    Text("全サイズ").tag(-1)
                    ForEach(clothingSizes.indices, id: \.self) { i in
                        Text("\(clothingSizes[i])").tag(i)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var searchButton: some View {
        Button {
            Task { await executeSearch() }
        } label: {
            Label("検索する", systemImage: "magnifyingglass")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo)
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
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(active ? Color.indigo : Color(.systemGray6))
                .foregroundColor(active ? .white : .primary)
                .cornerRadius(16)
        }
    }

    // MARK: - Search

    private func executeSearch() async {
        isLoading = true
        do {
            var query: Query = db.collection("posts")
                .whereField("is_hidden", isEqualTo: false)
                .order(by: "created_at", descending: true)
                .limit(to: 50)

            if selectedRegionIndex >= 0 {
                let code = String(format: "%02d", selectedRegionIndex + 1)
                query = query.whereField("region_code", isEqualTo: code)
            }
            if selectedGender != .unselected {
                query = query.whereField("gender_id", isEqualTo: selectedGender.rawValue)
            }
            if let w = selectedWeather {
                query = query.whereField("weather_type", isEqualTo: w.rawValue)
            }
            if !selectedMaxTempCategory.isEmpty {
                query = query.whereField("temp_max_category", isEqualTo: selectedMaxTempCategory)
            }
            if !selectedMinTempCategory.isEmpty {
                query = query.whereField("temp_min_category", isEqualTo: selectedMinTempCategory)
            }

            let snapshot = try await query.getDocuments()
            results = try snapshot.documents.map { try $0.data(as: Post.self) }
        } catch {
            // silently ignore search errors
        }
        isLoading = false
    }
}
