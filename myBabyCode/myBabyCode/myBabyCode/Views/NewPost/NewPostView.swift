import SwiftUI
import UIKit

extension View {
    func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

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

    // Item tagging
    @State private var taggingItemIndex: Int? = nil
    @State private var taggingSide: String = "front"

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

    // Draft
    @State private var showDiscardAlert = false
    @State private var showDraftSavedBanner = false

    private var hasDraftContent: Bool {
        !description.isEmpty || frontImage != nil || backImage != nil || !tempMax.isEmpty || !tempMin.isEmpty
    }

    private var children: [ChildProfile] { authViewModel.currentUser?.children ?? [] }

    var body: some View {
        NavigationView {
            ScrollView {
                mainForm
            }
            .overlay(alignment: .top) {
                if showDraftSavedBanner {
                    Text("下書きを保存しました")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.indigo.opacity(0.9))
                        .cornerRadius(20)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(), value: showDraftSavedBanner)
            .navigationTitle("新しい投稿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if hasDraftContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("下書き保存", isPresented: $showDiscardAlert) {
                Button("保存する") {
                    saveDraft()
                    dismiss()
                }
                Button("保存せずに閉じる", role: .destructive) {
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("入力内容を下書きとして保存しますか？")
            }
            .onAppear { applyProfileDefaults() }
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

    private var mainForm: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !children.isEmpty {
                childSection
                    .padding(.horizontal, 20)
                Divider().padding(.horizontal, 20)
            }
            photoSection
            if taggingItemIndex != nil {
                tagPlacementView
            }
            Divider().padding(.horizontal, 20)
            itemsSection
                .padding(.horizontal, 20)
            Divider().padding(.horizontal, 20)
            descriptionSection
                .padding(.horizontal, 20)
            Divider().padding(.horizontal, 20)
            weatherSection
                .padding(.horizontal, 20)
            draftSaveButton
                .padding(.horizontal, 20)
            postButton
                .padding(.horizontal, 20)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("服装のポイント")
            if #available(iOS 16.0, *) {
                TextField("例：気温が上がったので半袖デビュー！", text: $description, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: description, perform: { v in
                        if v.count > 100 { description = String(v.prefix(100)) }
                    })
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") { dismissKeyboard() }
                        }
                    }
            } else {
                TextEditor(text: $description)
                    .frame(minHeight: 80, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    .onChange(of: description, perform: { v in
                        if v.count > 100 { description = String(v.prefix(100)) }
                    })
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("完了") { dismissKeyboard() }
                        }
                    }
            }
            Text("\(description.count)/100")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var draftSaveButton: some View {
        Button {
            saveDraft()
        } label: {
            Label("下書きとして保存", systemImage: "square.and.arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.indigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.indigo.opacity(0.08))
                .cornerRadius(14)
        }
    }

    private var postButton: some View {
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
        .padding(.bottom, 40)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("写真（前面・背面）")
                .padding(.horizontal, 20)
            HStack(spacing: 16) {
                photoTile(title: "フロント", image: frontImage, target: .front)
                photoTile(title: "バック", image: backImage, target: .back)
            }
            .padding(.horizontal, 20)
            Text("どちらか1枚以上必須 • タップしてカメラまたはライブラリから選択")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)
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
            }
        }
    }

    // MARK: - Info Section (region only, gender comes from child)

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("地域")
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
    }

    @ViewBuilder
    private func tempField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundColor(.secondary)
            TextField("例: 25", text: text)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("完了") { dismissKeyboard() }
                    }
                }
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

            ForEach(items.indices, id: \.self) { idx in
                ItemEntryRow(entry: $items[idx], onRemove: {
                    items.remove(at: idx)
                }, onTag: {
                    taggingSide = frontImage != nil ? "front" : "back"
                    taggingItemIndex = idx
                })
            }
        }
    }

    // MARK: - Tag Placement View

    private var tagPlacementView: some View {
        let idx = taggingItemIndex!
        let entry = items.indices.contains(idx) ? items[idx] : nil
        let img = taggingSide == "front" ? frontImage : backImage
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("「\(entry?.brandName.isEmpty == false ? entry!.brandName : entry?.category.rawValue ?? "アイテム")」の位置をタップ")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    taggingItemIndex = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.indigo)

            HStack(spacing: 12) {
                ForEach(["front", "back"], id: \.self) { side in
                    let hasImg = side == "front" ? frontImage != nil : backImage != nil
                    if hasImg {
                        Button {
                            taggingSide = side
                        } label: {
                            Text(side == "front" ? "フロント" : "バック")
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(taggingSide == side ? Color.indigo : Color(.systemGray5))
                                .foregroundColor(taggingSide == side ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            if let uiImg = img {
                GeometryReader { geo in
                    let imgH = uiImg.size.height / uiImg.size.width * geo.size.width
                    ZStack {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { val in
                                        guard items.indices.contains(idx) else { return }
                                        let ratioX = val.location.x / geo.size.width
                                        let ratioY = val.location.y / imgH
                                        items[idx].tagPosition = CGPoint(x: ratioX, y: ratioY)
                                        items[idx].tagSide = taggingSide
                                        taggingItemIndex = nil
                                    }
                            )
                        ForEach(items.indices, id: \.self) { i in
                            tagDotOverlay(items: items, i: i, side: taggingSide,
                                          geoWidth: geo.size.width, imgH: imgH)
                        }
                    }
                }
                .frame(height: UIScreen.main.bounds.width * CGFloat(uiImg.size.height / uiImg.size.width))
            } else {
                Text("写真を先に追加してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func tagDotOverlay(items: [NewItemEntry], i: Int, side: String,
                                geoWidth: CGFloat, imgH: CGFloat) -> some View {
        if let pos = items[i].tagPosition, items[i].tagSide == side {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                Circle()
                    .stroke(Color.indigo, lineWidth: 2)
                    .frame(width: 20, height: 20)
            }
            .position(x: pos.x * geoWidth, y: pos.y * imgH)
        }
    }

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
        loadDraftIfNeeded()
    }

    // MARK: - Draft

    private struct DraftItem: Codable {
        let id: String
        let category: String
        let brandName: String
        let selectedSize: Int
    }

    private struct PostDraft: Codable {
        let description: String
        let regionIndex: Int
        let weatherType: String
        let tempMax: String
        let tempMin: String
        let items: [DraftItem]
    }

    private func saveDraft() {
        let draftItems = items.map { entry in
            DraftItem(id: entry.id.uuidString, category: entry.category.rawValue,
                      brandName: entry.brandName, selectedSize: entry.selectedSize)
        }
        let draft = PostDraft(
            description: description,
            regionIndex: selectedRegionIndex,
            weatherType: weatherType.rawValue,
            tempMax: tempMax,
            tempMin: tempMin,
            items: draftItems
        )
        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: "postDraft")
        }
        withAnimation { showDraftSavedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showDraftSavedBanner = false }
        }
    }

    private func loadDraftIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: "postDraft"),
              let draft = try? JSONDecoder().decode(PostDraft.self, from: data) else { return }
        description = draft.description
        selectedRegionIndex = draft.regionIndex
        weatherType = WeatherType(rawValue: draft.weatherType) ?? .sunny
        tempMax = draft.tempMax
        tempMin = draft.tempMin
        items = draft.items.map { di -> NewItemEntry in
            var entry = NewItemEntry(category: ItemCategory(rawValue: di.category) ?? .tops)
            entry.brandName = di.brandName
            entry.selectedSize = di.selectedSize
            return entry
        }
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

        // Create mapping from original indices to filtered indices
        var originalToFilteredIndex: [Int: Int] = [:]
        var filteredIndex = 0
        for originalIndex in items.indices {
            let name = items[originalIndex].brandName.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                originalToFilteredIndex[originalIndex] = filteredIndex
                filteredIndex += 1
            }
        }

        let tags: [PostItemTag] = items.indices.compactMap { idx -> PostItemTag? in
            guard let pos = items[idx].tagPosition else { return nil }
            guard let filteredIdx = originalToFilteredIndex[idx] else { return nil }
            return PostItemTag(
                item_index: filteredIdx,
                x_ratio: Double(pos.x),
                y_ratio: Double(pos.y),
                image_side: items[idx].tagSide
            )
        }
        var collectedTags: [PostItemTag] = tags
        postsViewModel.setPendingItemTags(collectedTags)

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

        if success {
            UserDefaults.standard.removeObject(forKey: "postDraft")
            showSuccess = true
        } else { showError = true }
    }
}

// MARK: - Extension for PostsViewModel setter

extension PostsViewModel {
    func setPendingItemTags(_ tags: [PostItemTag]) {
        self.pendingItemTags = tags
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
    var tagPosition: CGPoint? = nil  // 写真上のタグ位置（比率座標 0.0–1.0）
    var tagSide: String = "front"     // "front" or "back"
}

struct ItemEntryRow: View {
    @Binding var entry: NewItemEntry
    var onRemove: () -> Void
    var onTag: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .foregroundColor(.indigo)
                    .cornerRadius(10)
                Spacer()
                // Tag button
                Button(action: onTag) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.tagPosition != nil ? "mappin.circle.fill" : "mappin.circle")
                            .font(.system(size: 16))
                            .foregroundColor(entry.tagPosition != nil ? .indigo : .secondary)
                        if entry.tagPosition != nil {
                            Text(entry.tagSide == "front" ? "F" : "B")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.indigo)
                        }
                    }
                }
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
    @State private var canvasOffset: CGPoint = .zero
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
            let imgW = image.size.width
            let imgH = image.size.height
            let fitScale = min(geo.size.width / imgW, geo.size.height / imgH)
            let dispW = imgW * fitScale
            let dispH = imgH * fitScale
            let offsetX = (geo.size.width - dispW) / 2
            let offsetY = (geo.size.height - dispH) / 2

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear {
                        canvasSize = CGSize(width: dispW, height: dispH)
                        canvasOffset = CGPoint(x: offsetX, y: offsetY)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { val in
                                let stamp = PlacedStamp(kind: selectedKind, position: val.location)
                                stampItems.append(stamp)
                                history.append(.addStamp(stamp))
                                activeStampId = stamp.id
                            }
                    )
                ForEach($stampItems) { $stamp in
                    StampView(stamp: $stamp,
                              isActive: activeStampId == stamp.id,
                              onTap: { activeStampId = stamp.id },
                              onRemove: {
                                history.append(.removeStamp(stamp))
                                stampItems.removeAll { $0.id == stamp.id }
                              })
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
        // canvasSize はaspectFit後の実際の表示サイズ
        let dispW = canvasSize.width == 0 ? UIScreen.main.bounds.width : canvasSize.width
        let dispH = canvasSize.height == 0 ? UIScreen.main.bounds.height : canvasSize.height
        let fitScale = min(dispW / imgW, dispH / imgH)
        // キャンバス上での画像左上座標 (= canvasOffset)
        let offsetX = canvasOffset.x
        let offsetY = canvasOffset.y

        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH), format: format)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: imgW, height: imgH)))
            for stamp in stampItems {
                // stamp.position はジオメトリ全体上の座標 → 画像左上からの相対座標に変換
                let imgX = (stamp.position.x - offsetX) / fitScale
                let imgY = (stamp.position.y - offsetY) / fitScale
                // ビュー上のスタンプ描画サイズは StampView と同じ baseSize=44
                let baseViewPt: CGFloat = 44
                let stampViewPt = baseViewPt * stamp.scale
                let stampImgPt = stampViewPt / fitScale
                let drawImage: UIImage?
                switch stamp.kind {
                case .symbol(let sym):
                    let config = UIImage.SymbolConfiguration(pointSize: stampImgPt, weight: .bold)
                    let baseImg = UIImage(systemName: sym.rawValue, withConfiguration: config)
                    drawImage = baseImg?.withTintColor(UIColor(sym.color), renderingMode: .alwaysOriginal)
                case .image(let name):
                    drawImage = UIImage(named: name)
                }
                if let img = drawImage {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.translateBy(x: imgX, y: imgY)
                    ctx.cgContext.rotate(by: CGFloat(stamp.rotation.radians))
                    img.draw(in: CGRect(x: -stampImgPt / 2, y: -stampImgPt / 2, width: stampImgPt, height: stampImgPt))
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

    private let baseSize: CGFloat = 44

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1.0
    @GestureState private var rotationAngle: Angle = .zero

    var body: some View {
        Group {
            switch stamp.kind {
            case .symbol(let sym):
                Image(systemName: sym.rawValue)
                    .font(.system(size: baseSize))
                    .foregroundColor(sym.color)
            case .image(let name):
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: baseSize, height: baseSize)
            }
        }
        .frame(width: baseSize, height: baseSize)
        .scaleEffect(stamp.scale * pinchScale)
        .rotationEffect(stamp.rotation + rotationAngle)
        .shadow(color: .black.opacity(0.2), radius: 2)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: baseSize * stamp.scale + 12, height: baseSize * stamp.scale + 12)
                // 1本指スケールハンドル
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.indigo.opacity(0.8))
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                    }
                    Spacer()
                }
                .frame(width: baseSize * stamp.scale + 12, height: baseSize * stamp.scale + 12)
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

