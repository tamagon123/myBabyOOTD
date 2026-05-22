import SwiftUI
import PhotosUI

// MARK: - Item category

enum ItemCategory: String, CaseIterable, Identifiable {
    case tops       = "トップス"
    case bottoms    = "ボトムス"
    case accessory  = "アクセサリ"
    case other      = "その他"
    var id: String { rawValue }
}

struct NewItemEntry: Identifiable {
    let id = UUID()
    var category: ItemCategory
    var brandName: String = ""
    var selectedSize: Int = 70
    var isDefault: Bool = false     // true = デフォルト固定行（削除不可）
}

// MARK: - NewPostView

struct NewPostView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var frontItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?

    @State private var description: String = ""
    @State private var selectedRegionIndex: Int = 12
    @State private var selectedGender: ChildGender = .unselected
    @State private var selectedChildId: String? = nil
    @State private var weatherType: WeatherType = .sunny
    @State private var tempMax: String = ""
    @State private var tempMin: String = ""
    @State private var isFetchingWeather: Bool = false

    @State private var items: [NewItemEntry] = [
        NewItemEntry(category: .tops,      isDefault: true),
        NewItemEntry(category: .bottoms,   isDefault: true),
        NewItemEntry(category: .accessory, isDefault: true)
    ]
    @State private var showSuccess = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoSection
                    Divider().padding(.horizontal)
                    childSection
                    Divider().padding(.horizontal)
                    weatherSection
                    Divider().padding(.horizontal)
                    itemsSection
                    descriptionSection
                    postButton
                }
                .padding(.top, 16)
            }
            .navigationTitle("新しい投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { loadDefaults() }
            .alert("投稿完了！", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("コーディネートを共有しました🎉")
            }
            .alert("投稿エラー", isPresented: $showError) {
                Button("OK") { postsViewModel.errorMessage = nil }
            } message: {
                Text(postsViewModel.errorMessage ?? "不明なエラーが発生しました。")
            }
            .onChange(of: postsViewModel.errorMessage) { _, msg in
                if let msg = msg, !msg.isEmpty {
                    showError = true
                }
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("写真（前面・背面）")
            HStack(spacing: 16) {
                photoPickerTile(title: "フロント", image: frontImage, item: $frontItem) { frontImage = $0 }
                photoPickerTile(title: "バック",   image: backImage,  item: $backItem)  { backImage  = $0 }
            }
            .padding(.horizontal)
            Text("どちらか1枚以上必須")
                .font(.caption).foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func photoPickerTile(
        title: String, image: UIImage?,
        item: Binding<PhotosPickerItem?>,
        onLoad: @escaping (UIImage) -> Void
    ) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            ZStack {
                if let img = image {
                    Image(uiImage: img).resizable().scaledToFill().clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28)).foregroundColor(.indigo.opacity(0.5))
                        Text(title).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity).frame(height: 140)
            .background(Color(.systemIndigo).opacity(0.06)).cornerRadius(16)
        }
        .onChange(of: item.wrappedValue) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) { onLoad(img) }
            }
        }
    }

    // MARK: - Child Section

    private var childSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("基本情報")

            if authViewModel.children.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.circle").foregroundColor(.orange)
                    Text("プロフィールからお子様を登録してください")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(.systemYellow).opacity(0.15))
                .cornerRadius(10)
                .padding(.horizontal)
            } else {
                // 子供選択
                VStack(alignment: .leading, spacing: 6) {
                    Text("お子様を選択").font(.subheadline).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(authViewModel.children) { child in
                                let isSelected = selectedChildId == child.child_id
                                Button {
                                    selectedChildId = child.child_id
                                    applyChildInfo(child)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(ChildGender(rawValue: child.gender)?.emoji ?? "🧒")
                                            .font(.title2)
                                        Text(child.name.isEmpty ? "未設定" : child.name)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(isSelected ? .white : .primary)
                                        let months = Calendar.current.dateComponents([.month], from: child.birthday, to: Date()).month ?? 0
                                        Text(months < 12 ? "生後\(months)m" : "\(months/12)歳")
                                            .font(.system(size: 10))
                                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(isSelected ? Color.indigo : Color(.systemGray6))
                                    .cornerRadius(14)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 地域（アカウントから自動取得、変更可）
                VStack(alignment: .leading, spacing: 6) {
                    Text("地域").font(.subheadline).foregroundColor(.secondary)
                    Picker("地域", selection: $selectedRegionIndex) {
                        ForEach(prefectures.indices, id: \.self) { i in Text(prefectures[i]).tag(i) }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10).background(Color(.systemGray6)).cornerRadius(10)
                    .onChange(of: selectedRegionIndex) { _, _ in fetchWeather() }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Weather Section

    private var weatherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                sectionLabel("天気・気温")
                Spacer()
                if isFetchingWeather {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button { fetchWeather() } label: {
                        Label("自動取得", systemImage: "arrow.clockwise")
                            .font(.caption).foregroundColor(.indigo)
                    }
                }
            }
            HStack(spacing: 8) {
                ForEach(WeatherType.allCases) { w in
                    Button { weatherType = w } label: {
                        VStack(spacing: 2) {
                            Text(w.emoji).font(.title3)
                            Text(w.label).font(.system(size: 10))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(weatherType == w ? Color.indigo.opacity(0.12) : Color(.systemGray6))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(weatherType == w ? Color.indigo : Color.clear, lineWidth: 1.5))
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                }
            }
            HStack(spacing: 16) {
                tempField(label: "最高気温(℃)", text: $tempMax)
                tempField(label: "最低気温(℃)", text: $tempMin)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func tempField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField("例: 25", text: text).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Items Section

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionLabel("アイテム")
                Spacer()
                Button {
                    items.append(NewItemEntry(category: .other, isDefault: false))
                } label: {
                    Label("追加", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.indigo)
                }
            }
            ForEach($items) { $entry in
                ItemEntryRow(entry: $entry, canRemove: !entry.isDefault) {
                    items.removeAll { $0.id == entry.id }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("服装のポイント")
            TextField("例：気温が上がったので半袖デビュー！", text: $description, axis: .vertical)
                .lineLimit(3...5).textFieldStyle(.roundedBorder)
                .onChange(of: description) { _, v in
                    if v.count > 100 { description = String(v.prefix(100)) }
                }
            Text("\(description.count)/100").font(.caption).foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Post button

    private var postButton: some View {
        Button {
            Task { await submitPost() }
        } label: {
            Text(postButtonLabel)
                .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canPost ? Color.indigo : Color.gray).cornerRadius(16)
        }
        .disabled(!canPost || postsViewModel.isLoading)
        .padding(.horizontal).padding(.bottom, 32)
    }

    // MARK: - Helpers

    private var canPost: Bool {
        let hasPhoto = frontImage != nil || backImage != nil
        let hasChild = !authViewModel.children.isEmpty
        return hasPhoto && hasChild
    }

    private var postButtonLabel: String {
        if authViewModel.children.isEmpty { return "プロフィールからお子様を登録してください" }
        if frontImage == nil && backImage == nil { return "写真を1枚以上選択してください" }
        return postsViewModel.isLoading ? "投稿中..." : "投稿する"
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
    }

    private func loadDefaults() {
        guard let user = authViewModel.currentUser else { return }
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
        // 子供が1人だけなら自動選択
        if authViewModel.children.count == 1, let child = authViewModel.children.first {
            selectedChildId = child.child_id
            applyChildInfo(child)
        }
        fetchWeather()
    }

    private func applyChildInfo(_ child: Child) {
        selectedGender = ChildGender(rawValue: child.gender) ?? .unselected
    }

    private func fetchWeather() {
        let code = String(format: "%02d", selectedRegionIndex + 1)
        isFetchingWeather = true
        Task {
            if let result = await WeatherService.shared.fetch(regionCode: code) {
                tempMax = String(format: "%.0f", result.tempMax)
                tempMin = String(format: "%.0f", result.tempMin)
                weatherType = WeatherType(rawValue: result.weatherType) ?? .sunny
            }
            isFetchingWeather = false
        }
    }

    private func submitPost() async {
        guard let user = authViewModel.currentUser else {
            postsViewModel.errorMessage = "ユーザー情報が取得できません。再ログインしてください。"
            showError = true
            return
        }
        let regionCode = String(format: "%02d", selectedRegionIndex + 1)
        let tMax = Double(tempMax) ?? 20
        let tMin = Double(tempMin) ?? 15

        let postItems = items.compactMap { entry -> PostItem? in
            let name = entry.brandName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return PostItem(
                item_id: UUID().uuidString,
                brand_id: entry.category.rawValue,
                custom_name: name,
                size_value: entry.selectedSize
            )
        }

        let success = await postsViewModel.uploadPost(
            frontImage: frontImage,
            backImage: backImage,
            description: description,
            regionCode: regionCode,
            genderId: selectedGender.rawValue,
            weatherType: weatherType.rawValue,
            tempMax: tMax,
            tempMin: tMin,
            items: postItems,
            childId: selectedChildId,
            user: user
        )

        if success { showSuccess = true } else { showError = true }
    }
}

// MARK: - ItemEntryRow

struct ItemEntryRow: View {
    @Binding var entry: NewItemEntry
    var canRemove: Bool
    var onRemove: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Category label
                Text(entry.category.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.indigo)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1)).cornerRadius(8)

                if !entry.isDefault {
                    Picker("カテゴリ", selection: $entry.category) {
                        ForEach(ItemCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }

                Spacer()

                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill").foregroundColor(.red.opacity(0.7))
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("ブランド名（例: UNIQLO）", text: $entry.brandName)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)

                Picker("サイズ", selection: $entry.selectedSize) {
                    ForEach(clothingSizes, id: \.self) { s in Text("\(s)cm").tag(s) }
                }
                .pickerStyle(.menu).frame(width: 90)
                .padding(8).background(Color(.systemGray6)).cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
}
