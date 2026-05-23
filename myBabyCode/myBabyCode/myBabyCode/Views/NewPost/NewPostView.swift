import SwiftUI
import PhotosUI
import UIKit

// MARK: - NewPostView

struct NewPostView: View {
    @EnvironmentObject var postsViewModel: PostsViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Photo
    @State private var frontImage: UIImage?
    @State private var backImage: UIImage?
    @State private var photoSourceTarget: PhotoTarget = .front
    @State private var showPhotoSourceSheet = false
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var editingImage: UIImage?
    @State private var showImageEditor = false

    // Post info
    @State private var description: String = ""
    @State private var selectedRegionIndex: Int = 12
    @State private var selectedGender: ChildGender = .unselected
    @State private var weatherType: WeatherType = .sunny
    @State private var tempMax: String = ""
    @State private var tempMin: String = ""
    @State private var isFetchingWeather: Bool = false

    // Child selection
    @State private var selectedChildIndex: Int = 0

    // Items — default: tops, bottoms, accessory
    @State private var items: [NewItemEntry] = [
        NewItemEntry(category: .tops),
        NewItemEntry(category: .bottoms),
        NewItemEntry(category: .accessory)
    ]

    @State private var showSuccess = false
    @State private var showError = false

    private var children: [ChildProfile] { authViewModel.currentUser?.children ?? [] }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photoSection
                    Divider().padding(.horizontal)
                    if !children.isEmpty { childSection }
                    if !children.isEmpty { Divider().padding(.horizontal) }
                    infoSection
                    Divider().padding(.horizontal)
                    weatherSection
                    Divider().padding(.horizontal)
                    itemsSection

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
            .onAppear { applyProfileDefaults() }
            // カメラ or ライブラリ選択
            .confirmationDialog("写真を選択", isPresented: $showPhotoSourceSheet, titleVisibility: .visible) {
                Button("カメラで撮影") {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
                Button("ライブラリから選択") {
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: imagePickerSourceType) { img in
                    editingImage = img
                    showImageEditor = true
                }
            }
            .sheet(isPresented: $showImageEditor) {
                if let img = editingImage {
                    PhotoEditorView(image: img) { edited in
                        if photoSourceTarget == .front {
                            frontImage = edited
                        } else {
                            backImage = edited
                        }
                    }
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
                photoTile(title: "フロント", image: frontImage, target: .front)
                photoTile(title: "バック", image: backImage, target: .back)
            }
            .padding(.horizontal)
            Text("どちらか1枚以上必須 • タップしてカメラまたはライブラリから選択")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func photoTile(title: String, image: UIImage?, target: PhotoTarget) -> some View {
        Button {
            photoSourceTarget = target
            showPhotoSourceSheet = true
        } label: {
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
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.indigo.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Child Section

    private var childSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("投稿するお子様")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(children.indices, id: \.self) { idx in
                        let child = children[idx]
                        Button {
                            selectedChildIndex = idx
                        } label: {
                            VStack(spacing: 4) {
                                Text(ChildGender(rawValue: child.gender)?.emoji ?? "🧒")
                                    .font(.title2)
                                Text(child.name.isEmpty ? "子供\(idx+1)" : child.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(selectedChildIndex == idx ? .white : .primary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedChildIndex == idx ? Color.indigo : Color(.systemGray6))
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("基本情報")

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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("地域").font(.subheadline).foregroundColor(.secondary)
                    Spacer()
                    Text("プロフィールから反映")
                        .font(.caption2)
                        .foregroundColor(.indigo)
                }
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
                Menu {
                    ForEach(ItemCategory.allCases) { cat in
                        Button(cat.rawValue) {
                            items.append(NewItemEntry(category: cat))
                        }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.indigo)
                        .font(.system(size: 22))
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

    private var canPost: Bool { frontImage != nil || backImage != nil }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
    }

    private func applyProfileDefaults() {
        guard let user = authViewModel.currentUser else { return }
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
        selectedGender = ChildGender(rawValue: user.child_gender) ?? .unselected
        fetchWeather()
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

        // 子供が登録されている場合、選択中の子供情報を使う
        let selectedChild: ChildProfile? = children.indices.contains(selectedChildIndex) ? children[selectedChildIndex] : nil
        let effectiveBirthday = selectedChild?.birthday ?? user.child_birthday
        let effectiveGender = selectedChild.map { ChildGender(rawValue: $0.gender)?.rawValue ?? selectedGender.rawValue } ?? selectedGender.rawValue

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
                size_value: entry.selectedSize,
                category: entry.category.rawValue
            )
        }

        // ageMonths を選択した子供の誕生日から計算
        var modUser = user
        modUser.child_birthday = effectiveBirthday
        modUser.child_gender = effectiveGender

        let success = await postsViewModel.uploadPost(
            frontImage: frontImage,
            backImage: backImage,
            description: description,
            regionCode: regionCode,
            genderId: effectiveGender,
            weatherType: weatherType.rawValue,
            tempMax: tMax,
            tempMin: tMin,
            items: postItems,
            user: modUser
        )

        if success { showSuccess = true } else { showError = true }
    }
}

// MARK: - Supporting types

enum PhotoTarget { case front, back }

// MARK: - Item Entry

struct NewItemEntry: Identifiable {
    let id = UUID()
    var category: ItemCategory = .tops
    var brandName: String = ""
    var selectedSize: Int = 70
}

struct ItemEntryRow: View {
    @Binding var entry: NewItemEntry
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // Category badge
                Text(entry.category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .foregroundColor(.indigo)
                    .cornerRadius(10)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
            }
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
            }
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.6))
        .cornerRadius(12)
    }
}

// MARK: - ImagePickerView (UIImagePickerController wrapper)

struct ImagePickerView: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var onImagePicked: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        init(onImagePicked: @escaping (UIImage) -> Void) { self.onImagePicked = onImagePicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                onImagePicked(img)
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - PhotoEditorView (トリミング + スタンプ)

struct PhotoEditorView: View {
    let image: UIImage
    var onDone: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var stampItems: [PlacedStamp] = []
    @State private var cropRect: CGRect = .zero
    @State private var imageSize: CGSize = .zero
    @State private var selectedStamp: String = "⭐️"
    @State private var isCropMode: Bool = false
    @State private var cropStart: CGPoint = .zero
    @State private var cropEnd: CGPoint = .zero
    @State private var hasCrop: Bool = false

    private let stamps = ["⭐️","❤️","🌟","🙈","🙉","🙊","🌈","🎀","🎵","🔵","⬜️","🟡","😊","🐾","🍀"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stamp palette
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(stamps, id: \.self) { s in
                            Button(s) { selectedStamp = s }
                                .font(.system(size: 28))
                                .padding(6)
                                .background(selectedStamp == s ? Color.indigo.opacity(0.15) : Color.clear)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemGray6))

                // Mode toggle
                HStack {
                    Button {
                        isCropMode = false
                    } label: {
                        Label("スタンプ", systemImage: "face.smiling")
                            .font(.system(size: 13, weight: isCropMode ? .regular : .bold))
                            .foregroundColor(isCropMode ? .secondary : .indigo)
                    }
                    Spacer()
                    Button {
                        isCropMode = true
                    } label: {
                        Label("トリミング", systemImage: "crop")
                            .font(.system(size: 13, weight: isCropMode ? .bold : .regular))
                            .foregroundColor(isCropMode ? .indigo : .secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                // Canvas
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .onAppear {
                                let scale = min(geo.size.width / image.size.width, geo.size.height / image.size.height)
                                imageSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                            }
                            .gesture(
                                isCropMode
                                ? nil
                                : DragGesture(minimumDistance: 0)
                                    .onEnded { val in
                                        let pos = val.location
                                        stampItems.append(PlacedStamp(emoji: selectedStamp, position: pos))
                                    }
                            )

                        // Crop overlay
                        if isCropMode && hasCrop {
                            let rect = normalizedCropRect(in: geo.size)
                            Rectangle()
                                .stroke(Color.white, lineWidth: 2)
                                .background(Color.clear)
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.minX, y: rect.minY)
                        }

                        // Crop gesture overlay
                        if isCropMode {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture()
                                        .onChanged { val in
                                            if !hasCrop { cropStart = val.startLocation }
                                            cropEnd = val.location
                                            hasCrop = true
                                        }
                                )
                        }

                        // Stamps
                        ForEach(stampItems) { stamp in
                            Text(stamp.emoji)
                                .font(.system(size: 48))
                                .position(stamp.position)
                                .gesture(
                                    TapGesture(count: 2).onEnded {
                                        stampItems.removeAll { $0.id == stamp.id }
                                    }
                                )
                        }
                    }
                }

                Text(isCropMode ? "ドラッグでトリミング範囲を選択" : "タップでスタンプを配置 • スタンプをダブルタップで削除")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .navigationTitle("写真を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        let result = renderImage()
                        onDone(result)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.indigo)
                }
            }
        }
    }

    private func normalizedCropRect(in size: CGSize) -> CGRect {
        let minX = min(cropStart.x, cropEnd.x)
        let minY = min(cropStart.y, cropEnd.y)
        let w = abs(cropEnd.x - cropStart.x)
        let h = abs(cropEnd.y - cropStart.y)
        return CGRect(x: minX, y: minY, width: max(w, 4), height: max(h, 4))
    }

    private func renderImage() -> UIImage {
        let renderer = ImageRenderer(content:
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: image.size.width, height: image.size.height)
                ForEach(stampItems) { stamp in
                    Text(stamp.emoji)
                        .font(.system(size: image.size.width * 0.12))
                        .position(x: stamp.position.x * (image.size.width / UIScreen.main.bounds.width),
                                  y: stamp.position.y * (image.size.height / UIScreen.main.bounds.height))
                }
            }
            .frame(width: image.size.width, height: image.size.height)
        )
        renderer.scale = 1.0
        return renderer.uiImage ?? image
    }
}

struct PlacedStamp: Identifiable {
    let id = UUID()
    var emoji: String
    var position: CGPoint
}
