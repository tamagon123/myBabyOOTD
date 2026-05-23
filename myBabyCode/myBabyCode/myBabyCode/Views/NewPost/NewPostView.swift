import SwiftUI
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
    @State private var editorReadyImage: UIImage?
    @State private var showEditConfirm = false

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
            .sheet(isPresented: $showImagePicker, onDismiss: {
                if editingImage != nil {
                    showEditConfirm = true
                }
            }) {
                ImagePickerView(sourceType: imagePickerSourceType) { img in
                    editingImage = img
                }
            }
            .confirmationDialog("この写真を編集しますか？", isPresented: $showEditConfirm, titleVisibility: .visible) {
                Button("編集する（スタンプ・トリミング）") {
                    editorReadyImage = editingImage
                    editingImage = nil
                    showImageEditor = true
                }
                Button("そのまま使う") {
                    if photoSourceTarget == .front {
                        frontImage = editingImage
                    } else {
                        backImage = editingImage
                    }
                    editingImage = nil
                }
                Button("キャンセル", role: .cancel) {
                    editingImage = nil
                }
            }
            .sheet(isPresented: $showImageEditor, onDismiss: {
                editorReadyImage = nil
            }) {
                if let img = editorReadyImage {
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
                Button("OK") {
                    Task {
                        await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                        await postsViewModel.fetchLikedPosts()
                    }
                    dismiss()
                }
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

// MARK: - PhotoEditorView (スタンプ＋トリミング)

enum EditorMode { case stamp, crop }

struct PlacedStamp: Identifiable {
    let id = UUID()
    var symbol: StampSymbol
    var position: CGPoint
    var scale: CGFloat = 1.0
    var rotation: Angle = .zero
}

enum StampSymbol: String, CaseIterable, Identifiable {
    case circle       = "circle.fill"
    case square       = "square.fill"
    case triangle     = "triangle.fill"
    case star         = "star.fill"
    case heart        = "heart.fill"
    case diamond      = "diamond.fill"
    case pentagon     = "pentagon.fill"
    case hexagon      = "hexagon.fill"
    case cloud        = "cloud.fill"
    case moon         = "moon.fill"
    case sun          = "sun.max.fill"
    case bolt         = "bolt.fill"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .circle:   return .indigo
        case .square:   return .orange
        case .triangle: return .green
        case .star:     return .yellow
        case .heart:    return .pink
        case .diamond:  return .cyan
        case .pentagon: return .purple
        case .hexagon:  return .mint
        case .cloud:    return .blue
        case .moon:     return Color(.systemGray)
        case .sun:      return .orange
        case .bolt:     return .yellow
        }
    }
}

// Undo操作タイプ
enum EditorAction {
    case addStamp(PlacedStamp)
    case moveStamp(id: UUID, from: CGPoint, to: CGPoint)
    case scaleStamp(id: UUID, from: CGFloat, to: CGFloat)
    case removeStamp(PlacedStamp)
    case crop(from: UIImage, to: UIImage)
}

struct PhotoEditorView: View {
    @State private var currentImage: UIImage
    let onDone: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var stampItems: [PlacedStamp] = []
    @State private var selectedSymbol: StampSymbol = .star
    @State private var mode: EditorMode = .stamp
    @State private var history: [EditorAction] = []

    // Crop state
    @State private var canvasSize: CGSize = .zero
    @State private var cropTL: CGPoint = .zero  // top-left handle
    @State private var cropBR: CGPoint = .zero  // bottom-right handle
    @State private var cropInitialized = false

    // Stamp interaction
    @State private var activeStampId: UUID? = nil
    @State private var stampScaleBase: CGFloat = 1.0

    init(image: UIImage, onDone: @escaping (UIImage) -> Void) {
        _currentImage = State(initialValue: image)
        self.onDone = onDone
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                modeBar
                if mode == .stamp { stampPalette }
                canvas
                hintText
            }
            .navigationTitle("写真を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone(renderFinalImage())
                        dismiss()
                    } label: {
                        Text("完了").font(.system(size: 15, weight: .bold))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        applyCrop()
                    } label: {
                        Text("切り取り").font(.system(size: 14, weight: .bold))
                    }
                    .opacity(mode == .crop ? 1 : 0)
                    .disabled(mode != .crop)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(history.isEmpty)
                }
            }
        }
    }

    // MARK: - Mode Bar

    private var modeBar: some View {
        HStack(spacing: 0) {
            modeTab(title: "スタンプ", icon: "star.fill", target: .stamp)
            modeTab(title: "トリミング", icon: "crop", target: .crop)
        }
        .background(Color(.systemGray6))
    }

    private func modeTab(title: String, icon: String, target: EditorMode) -> some View {
        Button {
            mode = target
            if target == .crop && !cropInitialized { initCropHandles() }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 16))
                Text(title).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(mode == target ? .indigo : .secondary)
            .background(mode == target ? Color.white : Color(.systemGray6))
        }
    }

    // MARK: - Stamp Palette

    private var stampPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StampSymbol.allCases) { sym in
                    Button {
                        selectedSymbol = sym
                    } label: {
                        Image(systemName: sym.rawValue)
                            .font(.system(size: 24))
                            .foregroundColor(sym.color)
                            .frame(width: 44, height: 44)
                            .background(selectedSymbol == sym ? Color.indigo.opacity(0.12) : Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedSymbol == sym ? Color.indigo : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray5))
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                // Base image
                Image(uiImage: currentImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        canvasSize = geo.size
                        initCropHandles()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { val in
                                guard mode == .stamp else { return }
                                let stamp = PlacedStamp(symbol: selectedSymbol, position: val.location)
                                stampItems.append(stamp)
                                history.append(.addStamp(stamp))
                            }
                    )

                // Stamps
                ForEach($stampItems) { $stamp in
                    StampView(stamp: $stamp, isActive: activeStampId == stamp.id) {
                        activeStampId = stamp.id
                    } onRemove: {
                        history.append(.removeStamp(stamp))
                        stampItems.removeAll { $0.id == stamp.id }
                    } onScaleChange: { base in
                        stampScaleBase = base
                    }
                }

                // Crop overlay
                if mode == .crop {
                    cropOverlay(in: geo.size)
                }
            }
        }
    }

    // MARK: - Crop Overlay

    @ViewBuilder
    private func cropOverlay(in size: CGSize) -> some View {
        let rect = CGRect(
            x: cropTL.x, y: cropTL.y,
            width: cropBR.x - cropTL.x,
            height: cropBR.y - cropTL.y
        )
        // Dim outside
        ZStack {
            Color.black.opacity(0.4)
            Rectangle()
                .frame(width: max(rect.width, 0), height: max(rect.height, 0))
                .offset(x: rect.minX - size.width / 2 + rect.width / 2,
                        y: rect.minY - size.height / 2 + rect.height / 2)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .allowsHitTesting(false)

        // Crop border
        Rectangle()
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .position(x: rect.midX, y: rect.midY)
            .allowsHitTesting(false)

        // Grid lines
        Path { p in
            let dx = rect.width / 3
            let dy = rect.height / 3
            for i in 1..<3 {
                p.move(to: CGPoint(x: rect.minX + dx * CGFloat(i), y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + dx * CGFloat(i), y: rect.maxY))
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + dy * CGFloat(i)))
                p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + dy * CGFloat(i)))
            }
        }
        .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        .allowsHitTesting(false)

        // Handles
        cropHandle(at: cropTL, corner: .topLeft)
        cropHandle(at: CGPoint(x: cropBR.x, y: cropTL.y), corner: .topRight)
        cropHandle(at: CGPoint(x: cropTL.x, y: cropBR.y), corner: .bottomLeft)
        cropHandle(at: cropBR, corner: .bottomRight)
    }

    private enum CropCorner { case topLeft, topRight, bottomLeft, bottomRight }

    private func cropHandle(at point: CGPoint, corner: CropCorner) -> some View {
        let handleSize: CGFloat = 24
        return Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .shadow(radius: 2)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { val in
                        let minSize: CGFloat = 40
                        switch corner {
                        case .topLeft:
                            cropTL = CGPoint(
                                x: min(val.location.x, cropBR.x - minSize),
                                y: min(val.location.y, cropBR.y - minSize)
                            )
                        case .topRight:
                            cropBR.x = max(val.location.x, cropTL.x + minSize)
                            cropTL.y = min(val.location.y, cropBR.y - minSize)
                        case .bottomLeft:
                            cropTL.x = min(val.location.x, cropBR.x - minSize)
                            cropBR.y = max(val.location.y, cropTL.y + minSize)
                        case .bottomRight:
                            cropBR = CGPoint(
                                x: max(val.location.x, cropTL.x + minSize),
                                y: max(val.location.y, cropTL.y + minSize)
                            )
                        }
                    }
            )
    }

    // MARK: - Hint

    private var hintText: some View {
        Group {
            if mode == .stamp {
                Text("タップでスタンプを配置 • ピンチで拡縮・回転 • ダブルタップで削除")
            } else {
                Text("四隅のハンドルをドラッグして範囲を調整し「切り取り」をタップ")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }

    // MARK: - Crop Helpers

    private func initCropHandles() {
        guard canvasSize != .zero else { return }
        let inset: CGFloat = 20
        cropTL = CGPoint(x: inset, y: inset)
        cropBR = CGPoint(x: canvasSize.width - inset, y: canvasSize.height - inset)
        cropInitialized = true
    }

    private func applyCrop() {
        let imgW = currentImage.size.width
        let imgH = currentImage.size.height
        let dispW = canvasSize.width
        let dispH = canvasSize.height

        // scaledToFit で表示される実際の描画サイズを計算
        let scale = min(dispW / imgW, dispH / imgH)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let offsetX = (dispW - drawW) / 2
        let offsetY = (dispH - drawH) / 2

        // クロップ座標を画像座標に変換
        let imgScale = 1.0 / scale
        let cx = max(0, (cropTL.x - offsetX)) * imgScale
        let cy = max(0, (cropTL.y - offsetY)) * imgScale
        let cw = min(imgW - cx, (cropBR.x - cropTL.x) * imgScale)
        let ch = min(imgH - cy, (cropBR.y - cropTL.y) * imgScale)

        guard cw > 0, ch > 0 else { return }

        let cropRect = CGRect(x: cx, y: cy, width: cw, height: ch)
        if let cgImg = currentImage.cgImage?.cropping(to: cropRect) {
            let before = currentImage
            let cropped = UIImage(cgImage: cgImg, scale: currentImage.scale, orientation: currentImage.imageOrientation)
            history.append(.crop(from: before, to: cropped))
            currentImage = cropped
            // リセット
            cropInitialized = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                initCropHandles()
            }
        }
    }

    // MARK: - Undo

    private func performUndo() {
        guard let last = history.popLast() else { return }
        switch last {
        case .addStamp(let s):
            stampItems.removeAll { $0.id == s.id }
        case .removeStamp(let s):
            stampItems.append(s)
        case .moveStamp(let id, let from, _):
            if let idx = stampItems.firstIndex(where: { $0.id == id }) {
                stampItems[idx].position = from
            }
        case .scaleStamp(let id, let from, _):
            if let idx = stampItems.firstIndex(where: { $0.id == id }) {
                stampItems[idx].scale = from
            }
        case .crop(let before, _):
            currentImage = before
            cropInitialized = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                initCropHandles()
            }
        }
    }

    // MARK: - Render

    private func renderFinalImage() -> UIImage {
        let imgW = currentImage.size.width
        let imgH = currentImage.size.height
        let dispW = canvasSize.width == 0 ? UIScreen.main.bounds.width : canvasSize.width
        let dispH = canvasSize.height == 0 ? UIScreen.main.bounds.height : canvasSize.height

        let scale = min(dispW / imgW, dispH / imgH)
        let offsetX = (dispW - imgW * scale) / 2
        let offsetY = (dispH - imgH * scale) / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = currentImage.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH), format: format)
        return renderer.image { ctx in
            currentImage.draw(in: CGRect(origin: .zero, size: CGSize(width: imgW, height: imgH)))
            for stamp in stampItems {
                let imgX = (stamp.position.x - offsetX) / scale
                let imgY = (stamp.position.y - offsetY) / scale
                let baseSize: CGFloat = imgW * 0.1
                let stampSize = baseSize * stamp.scale
                let uiColor = UIColor(stamp.symbol.color)
                let config = UIImage.SymbolConfiguration(pointSize: stampSize, weight: .bold)
                if let sym = UIImage(systemName: stamp.symbol.rawValue, withConfiguration: config)?
                    .withTintColor(uiColor, renderingMode: .alwaysOriginal) {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.translateBy(x: imgX, y: imgY)
                    ctx.cgContext.rotate(by: CGFloat(stamp.rotation.radians))
                    sym.draw(at: CGPoint(x: -stampSize / 2, y: -stampSize / 2))
                    ctx.cgContext.restoreGState()
                }
            }
        }
    }
}

// MARK: - StampView (個別スタンプ操作)

struct StampView: View {
    @Binding var stamp: PlacedStamp
    let isActive: Bool
    let onTap: () -> Void
    let onRemove: () -> Void
    let onScaleChange: (CGFloat) -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var rotationAngle: Angle = .zero

    var body: some View {
        Image(systemName: stamp.symbol.rawValue)
            .font(.system(size: 44 * stamp.scale))
            .foregroundColor(stamp.symbol.color)
            .shadow(color: .black.opacity(0.2), radius: 2)
            .scaleEffect(pinchScale)
            .rotationEffect(stamp.rotation + rotationAngle)
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.8), lineWidth: 1)
                        .padding(-6)
                }
            }
            .position(
                x: stamp.position.x + dragOffset.width,
                y: stamp.position.y + dragOffset.height
            )
            .gesture(
                SimultaneousGesture(
                    SimultaneousGesture(
                        DragGesture()
                            .updating($dragOffset) { val, state, _ in state = val.translation }
                            .onEnded { val in
                                stamp.position.x += val.translation.width
                                stamp.position.y += val.translation.height
                            },
                        MagnificationGesture()
                            .updating($pinchScale) { val, state, _ in state = val }
                            .onEnded { val in
                                stamp.scale *= val
                            }
                    ),
                    RotationGesture()
                        .updating($rotationAngle) { val, state, _ in state = val }
                        .onEnded { val in
                            stamp.rotation += val
                        }
                )
            )
            .highPriorityGesture(
                TapGesture(count: 2).onEnded { onRemove() }
            )
            .onTapGesture { onTap() }
    }
}
