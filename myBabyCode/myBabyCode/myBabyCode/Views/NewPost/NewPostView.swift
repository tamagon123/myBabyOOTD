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
    @State private var showPhotoActionSheet = false

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
                Button("編集する（スタンプ）") {
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
            if image != nil {
                showPhotoActionSheet = true
            } else {
                showPhotoSourceSheet = true
            }
        } label: {
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                    // 編集アイコンバッジ
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                                .padding(6)
                        }
                    }
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
        .confirmationDialog("写真を変更", isPresented: Binding(
            get: { showPhotoActionSheet && photoSourceTarget == target },
            set: { if !$0 { showPhotoActionSheet = false } }
        ), titleVisibility: .visible) {
            Button("スタンプを編集") {
                let img = target == .front ? frontImage : backImage
                editorReadyImage = img
                showImageEditor = true
            }
            Button("写真を入れ替え") {
                showPhotoSourceSheet = true
            }
            Button("キャンセル", role: .cancel) {}
        }
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

// MARK: - PhotoEditorView (スタンプ)

// スタンプの種類：SF Symbol または Assets 画像
enum StampKind: Equatable {
    case symbol(StampSymbol)   // SF Symbols (デフォルト)
    case image(String)         // Assets.xcassets/StampImages/ の画像名
}

struct PlacedStamp: Identifiable {
    let id = UUID()
    var kind: StampKind
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
}

struct PhotoEditorView: View {
    let image: UIImage
    let onDone: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var stampItems: [PlacedStamp] = []
    @State private var selectedKind: StampKind = .symbol(.star)
    @State private var history: [EditorAction] = []
    @State private var canvasSize: CGSize = .zero
    @State private var activeStampId: UUID? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                stampPalette
                canvas
                hintText
            }
            .navigationTitle("スタンプを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        performUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(history.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDone(renderFinalImage())
                        dismiss()
                    } label: {
                        Text("完了").font(.system(size: 15, weight: .bold))
                    }
                }
            }
        }
    }

    // MARK: - Stamp Palette

    private var stampPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // SF Symbol スタンプ
                ForEach(StampSymbol.allCases) { sym in
                    let kind = StampKind.symbol(sym)
                    Button {
                        selectedKind = kind
                    } label: {
                        Image(systemName: sym.rawValue)
                            .font(.system(size: 24))
                            .foregroundColor(sym.color)
                            .frame(width: 44, height: 44)
                            .background(selectedKind == kind ? Color.indigo.opacity(0.12) : Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedKind == kind ? Color.indigo : Color.clear, lineWidth: 1.5)
                            )
                    }
                }
                // 画像スタンプ — StampImages/ に画像を追加しstampImageNamesに追記すると自動で出現
                if !stampImageNames.isEmpty {
                    Divider().frame(height: 32)
                    ForEach(stampImageNames, id: \.self) { name in
                        let kind = StampKind.image(name)
                        Button {
                            selectedKind = kind
                        } label: {
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .background(selectedKind == kind ? Color.indigo.opacity(0.12) : Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedKind == kind ? Color.indigo : Color.clear, lineWidth: 1.5)
                                )
                        }
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
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { canvasSize = geo.size }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { val in
                                let stamp = PlacedStamp(kind: selectedKind, position: val.location)
                                stampItems.append(stamp)
                                history.append(.addStamp(stamp))
                            }
                    )
                ForEach($stampItems) { $stamp in
                    StampView(stamp: $stamp, isActive: activeStampId == stamp.id) {
                        activeStampId = stamp.id
                    } onRemove: {
                        history.append(.removeStamp(stamp))
                        stampItems.removeAll { $0.id == stamp.id }
                    }
                }
            }
        }
    }

    // MARK: - Hint

    private var hintText: some View {
        Text("タップでスタンプを配置 • ピンチで拡縮・回転 • ダブルタップで削除")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
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
        }
    }

    // MARK: - Render

    private func renderFinalImage() -> UIImage {
        let imgW = image.size.width
        let imgH = image.size.height
        let dispW = canvasSize.width == 0 ? UIScreen.main.bounds.width : canvasSize.width
        let dispH = canvasSize.height == 0 ? UIScreen.main.bounds.height : canvasSize.height

        let scale = min(dispW / imgW, dispH / imgH)
        let offsetX = (dispW - imgW * scale) / 2
        let offsetY = (dispH - imgH * scale) / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH), format: format)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: imgW, height: imgH)))
            for stamp in stampItems {
                let imgX = (stamp.position.x - offsetX) / scale
                let imgY = (stamp.position.y - offsetY) / scale
                let baseSize: CGFloat = imgW * 0.18
                let stampSize = baseSize * stamp.scale
                let drawImage: UIImage?
                switch stamp.kind {
                case .symbol(let sym):
                    let config = UIImage.SymbolConfiguration(pointSize: stampSize, weight: .bold)
                    drawImage = UIImage(systemName: sym.rawValue, withConfiguration: config)?
                        .withTintColor(UIColor(sym.color), renderingMode: .alwaysOriginal)
                case .image(let name):
                    drawImage = UIImage(named: name)
                }
                if let img = drawImage {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.translateBy(x: imgX, y: imgY)
                    ctx.cgContext.rotate(by: CGFloat(stamp.rotation.radians))
                    img.draw(in: CGRect(x: -stampSize / 2, y: -stampSize / 2, width: stampSize, height: stampSize))
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

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var rotationAngle: Angle = .zero

    var body: some View {
        Group {
            switch stamp.kind {
            case .symbol(let sym):
                Image(systemName: sym.rawValue)
                    .font(.system(size: 100 * stamp.scale))
                    .foregroundColor(sym.color)
            case .image(let name):
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100 * stamp.scale, height: 100 * stamp.scale)
            }
        }
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

