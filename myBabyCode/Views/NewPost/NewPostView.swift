import SwiftUI
import PhotosUI

struct NewPostView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var frontItem: PhotosPickerItem?
    @State private var backItem: PhotosPickerItem?
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?

    @State private var description: String = ""
    @State private var selectedRegionIndex: Int = 12   // 東京都
    @State private var selectedGender: ChildGender = .unselected
    @State private var weatherType: WeatherType = .sunny
    @State private var tempMax: String = ""
    @State private var tempMin: String = ""
    @State private var isFetchingWeather: Bool = false

    @State private var items: [NewItemEntry] = [NewItemEntry()]
    @State private var showSuccess = false
    @State private var showError = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Photos
                    photoSection

                    Divider().padding(.horizontal)

                    // Basic info
                    infoSection

                    Divider().padding(.horizontal)

                    // Weather
                    weatherSection

                    Divider().padding(.horizontal)

                    // Items
                    itemsSection

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("服装のポイント")
                        TextField("例：気温が上がったので半袖デビュー！", text: $description, axis: .vertical)
                            .lineLimit(3...5)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: description) { v in
                                if v.count > 100 { description = String(v.prefix(100)) }
                            }
                        Text("\(description.count)/100")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Post button
                    Button {
                        Task { await submitPost() }
                    } label: {
                        Text(postsViewModel.isLoading ? "投稿中..." : "投稿する")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canPost ? Color.indigo : Color.gray)
                            .cornerRadius(16)
                    }
                    .disabled(!canPost || postsViewModel.isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
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
            .alert("投稿完了！", isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("コーディネートを共有しました🎉")
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(postsViewModel.errorMessage ?? "不明なエラーが発生しました。")
            }
        }
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("写真（前面・背面）")
            HStack(spacing: 16) {
                photoPickerTile(title: "フロント", image: frontImage, item: $frontItem) { img in
                    frontImage = img
                }
                photoPickerTile(title: "バック", image: backImage, item: $backItem) { img in
                    backImage = img
                }
            }
            .padding(.horizontal)
            Text("どちらか1枚以上必須")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func photoPickerTile(
        title: String,
        image: UIImage?,
        item: Binding<PhotosPickerItem?>,
        onLoad: @escaping (UIImage) -> Void
    ) -> some View {
        PhotosPicker(selection: item, matching: .images) {
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.indigo.opacity(0.5))
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(Color(.systemIndigo).opacity(0.06))
            .cornerRadius(16)
        }
        .onChange(of: item.wrappedValue) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    onLoad(img)
                }
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("基本情報")

            // Gender
            VStack(alignment: .leading, spacing: 6) {
                Text("性別").font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(ChildGender.allCases) { g in
                        Button {
                            selectedGender = g
                        } label: {
                            Text(g.label)
                                .font(.system(size: 13, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedGender == g ? Color.indigo : Color(.systemGray6))
                                .foregroundColor(selectedGender == g ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
            }

            // Region
            VStack(alignment: .leading, spacing: 6) {
                Text("地域").font(.subheadline).foregroundColor(.secondary)
                Picker("地域", selection: $selectedRegionIndex) {
                    ForEach(prefectures.indices, id: \.self) { i in
                        Text(prefectures[i]).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .onChange(of: selectedRegionIndex) { _ in
                    fetchWeather()
                }
            }
        }
        .padding(.horizontal)
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
                            .font(.caption)
                            .foregroundColor(.indigo)
                    }
                }
            }

            // Weather type
            HStack(spacing: 8) {
                ForEach(WeatherType.allCases) { w in
                    Button {
                        weatherType = w
                    } label: {
                        VStack(spacing: 2) {
                            Text(w.emoji).font(.title3)
                            Text(w.label).font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(weatherType == w ? Color.indigo.opacity(0.12) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(weatherType == w ? Color.indigo : Color.clear, lineWidth: 1.5)
                        )
                        .cornerRadius(12)
                    }
                    .foregroundColor(.primary)
                }
            }

            // Temps
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
            TextField("例: 25", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
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
                    items.append(NewItemEntry())
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.indigo)
                }
            }

            ForEach($items) { $entry in
                ItemEntryRow(entry: $entry) {
                    items.removeAll { $0.id == entry.id }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var canPost: Bool {
        frontImage != nil || backImage != nil
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.primary)
    }

    private func fetchWeather() {
        let code = String(format: "%02d", selectedRegionIndex + 1)
        isFetchingWeather = true
        Task {
            if let result = await WeatherService.shared.fetch(regionCode: code) {
                await MainActor.run {
                    tempMax = String(format: "%.0f", result.tempMax)
                    tempMin = String(format: "%.0f", result.tempMin)
                    weatherType = WeatherType(rawValue: result.weatherType) ?? .sunny
                }
            }
            await MainActor.run { isFetchingWeather = false }
        }
    }

    private func submitPost() async {
        guard let user = authViewModel.currentUser else { return }
        let regionCode = String(format: "%02d", selectedRegionIndex + 1)
        let tMax = Double(tempMax) ?? 20
        let tMin = Double(tempMin) ?? 15

        let postItems = items.compactMap { entry -> PostItem? in
            let name = entry.brandName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            return PostItem(
                item_id: UUID().uuidString,
                brand_id: "custom",
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
            user: user
        )

        if success {
            showSuccess = true
        } else {
            showError = true
        }
    }
}

// MARK: - Item Entry

struct NewItemEntry: Identifiable {
    let id = UUID()
    var brandName: String = ""
    var selectedSize: Int = 70
}

struct ItemEntryRow: View {
    @Binding var entry: NewItemEntry
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("ブランド名（例: UNIQLO）", text: $entry.brandName)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Picker("サイズ", selection: $entry.selectedSize) {
                ForEach(clothingSizes, id: \.self) { s in
                    Text("\(s)").tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
    }
}
