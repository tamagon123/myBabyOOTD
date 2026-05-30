// =============================================================================
// ファイル名: NewPostView.swift
// 役割: 新規投稿作成画面（写真選択・スタンプ編集・アイテム登録・天気情報・投稿）
// 説明:
//   ユーザーが子供のコーディネート写真を投稿するための画面です。
//   front（正面）とback（背面）の写真をカメラまたはライブラリから選択し、
//   スタンプ・テキストの写真編集、アイテム（洋服）情報の登録、
//   天気・気温・地域・子供選択、説明文入力などの一連の投稿フローを提供します。
//   投稿前に下書き保存も可能です。
// =============================================================================

import SwiftUI
import UIKit

// =============================================================================
// View拡張: キーボードを閉じるためのユーティリティ
// =============================================================================
extension View {
    func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - NewPostView

struct NewPostView: View {
    // === 環境オブジェクト ===
    @EnvironmentObject var postsViewModel: PostsViewModel  // 投稿作成処理
    @EnvironmentObject var authViewModel: AuthViewModel    // ユーザー情報（子供・地域）
    @EnvironmentObject var draftManager: DraftManager      // 下書き保存
    @Environment(\.dismiss) private var dismiss              // シートを閉じる

    // === 写真関連 ===
    @State private var frontImage: UIImage?              // 正面写真
    @State private var backImage: UIImage?               // 背面写真
    @State private var photoSourceTarget: PhotoTarget = .front  // 現在選択中の写真対象（front/back）
    @State private var showPhotoSourceSheet = false      // 写真ソース選択（カメラ/ライブラリ）シート
    @State private var showImagePicker = false           // UIImagePickerController表示フラグ
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var editingImage: UIImage?            // 編集中の画像（スタンプ編集画面へ渡す）
    @State private var showImageEditor = false           // スタンプ編集画面表示フラグ
    @State private var editorReadyImage: UIImage?        // 編集完了後の画像
    @State private var showEditConfirm = false           // 編集確認ダイアログ
    @State private var showPhotoActionSheet = false      // 写真再選択/編集アクションシート

    // === アイテムタグ関連 ===
    @State private var taggingItemIndex: Int? = nil      // タグ付け中のアイテムインデックス
    @State private var taggingSide: String = "front"    // タグ付け対象の画像面
    @State private var showNoPhotoAlert = false          // 写真未選択時タグ付けアラート

    // === 投稿情報 ===
    @State private var description: String = ""            // 投稿の説明文
    @State private var selectedRegionIndex: Int = 12     // 選択中の都道府県インデックス（デフォルト: 東京都）
    @State private var selectedGender: ChildGender = .unselected  // 選択中の子供性別
    @State private var weatherType: WeatherType = .sunny  // 選択中の天気
    @State private var tempMax: String = ""                // 最高気温（文字列入力）
    @State private var tempMin: String = ""                // 最低気温（文字列入力）
    @State private var isFetchingWeather: Bool = false    // 天気自動取得中フラグ

    // === 子供選択 ===
    @State private var selectedChildIndex: Int = 0        // 選択中の子供インデックス

    // === アイテム登録 ===
    // デフォルトで3つのアイテム（トップス・ボトムス・アクセサリー）を初期表示
    @State private var items: [NewItemEntry] = [
        NewItemEntry(category: .tops),
        NewItemEntry(category: .bottoms),
        NewItemEntry(category: .accessory)
    ]

    // === 状態通知 ===
    @State private var showSuccess = false                 // 投稿成功時の表示フラグ
    @State private var showError = false                  // 投稿失敗時の表示フラグ

    // === 下書き関連 ===
    @State private var draftSaved = false                  // 下書き保存済みフラグ
    @State private var showDraftSavedBanner = false       // 下書き保存成功バナー表示フラグ
    @State private var showDiscardAlert = false           // 変更破棄確認アラート
    @State private var editingDraftId: String? = nil      // 現在編集中の下書きID（上書き保存用）

    // 計算プロパティ: ログイン中ユーザーの子供リスト（プロフィール設定時に登録）
    private var children: [ChildProfile] { authViewModel.currentUser?.children ?? [] }
    
    // 変更があるかどうか
    private var hasChanges: Bool {
        frontImage != nil || backImage != nil || !items.isEmpty || !description.isEmpty
    }

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 新規投稿画面の全体レイアウトを定義
    // 構成:
    //   1. ScrollView内にmainForm（写真選択・アイテム登録・天気情報・説明文など）
    //   2. ツールバー（閉じるボタン、キーボード「完了」ボタン）
    //   3. 下書き保存成功バナーのオーバーレイ
    //   4. 各種シート・ピッカー・確認ダイアログ
    // =============================================================================
    var body: some View {
        NavigationView {
            ScrollView {
                mainForm
            }
            .background(Color(.systemBackground))
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { dismissKeyboard() }
                }
            }
            .overlay(alignment: .top) {
                if showDraftSavedBanner {
                    Text("下書きを保存しました")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.82))
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
                        if hasChanges {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("下書きを保存しますか？", isPresented: $showDiscardAlert) {
                Button("保存する") {
                    saveDraft()
                    dismiss()
                }
                Button("保存しない", role: .destructive) {
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("編集内容を下書きとして保存できます。")
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
                Text("コーディネートを共有しました")
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(postsViewModel.errorMessage ?? "不明なエラーが発生しました。")
            }
            .alert("写真を選択してください", isPresented: $showNoPhotoAlert) {
                Button("OK") {}
            } message: {
                Text("タグ付けを行う前に、コーディネートの写真を撮影または選択してください。")
            }
            .fullScreenCover(isPresented: Binding(
                get: { taggingItemIndex != nil },
                set: { if !$0 { taggingItemIndex = nil } }
            )) {
                if let idx = taggingItemIndex {
                    TagPlacementView(
                        items: $items,
                        itemIndex: idx,
                        taggingSide: $taggingSide,
                        frontImage: frontImage,
                        backImage: backImage
                    )
                }
            }
        }
    }

    // =============================================================================
    // 【Viewサマリー】mainForm
    // 目的: 新規投稿画面のメイン入力フォーム全体を構成する
    // 構成:
    //   - 子供選択（childSection）
    //   - 写真選択（photoSection）
    //   - 説明文入力（descriptionSection）
    //   - 天気・気温（weatherSection）
    //   - アイテム登録（itemsSection）
    //   - 下書き保存・投稿ボタン
    // =============================================================================
    private var mainForm: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !children.isEmpty {
                childSection
                    .padding(.horizontal, 20)
                Divider().padding(.horizontal, 20)
            }
            photoSection
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

            // バナー広告（サブスク登録で非表示可）
            AdBannerView()
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // =============================================================================
    // 【Viewサマリー】descriptionSection
    // 目的: 投稿の説明文（服装のポイント）を入力するTextEditorを表示する
    // 戻り値: some View
    // =============================================================================
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("服装のポイント")
            if #available(iOS 16.0, *) {
                TextField("例：気温が上がったので半西デビュー！", text: $description, axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: description, perform: { v in
                        if v.count > 100 { description = String(v.prefix(100)) }
                    })
            } else {
                TextEditor(text: $description)
                    .frame(minHeight: 80, maxHeight: 120)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                    .onChange(of: description, perform: { v in
                        if v.count > 100 { description = String(v.prefix(100)) }
                    })
            }
            Text("\(description.count)/100")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // =============================================================================
    // 【Viewサマリー】draftSaveButton
    // 目的: 現在の入力内容を下書きとして保存するボタン
    // 処理: saveDraft()を呼び出し、保存成功時にバナーを表示する
    // 戻り値: some View
    // =============================================================================
    private var draftSaveButton: some View {
        Button {
            saveDraft()
        } label: {
            Label("下書きとして保存", systemImage: "square.and.arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(draftSaved ? .secondary : Color.accentGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(draftSaved ? Color(.systemGray5) : Color.accentGreen.opacity(0.1))
                .cornerRadius(14)
        }
        .disabled(draftSaved)
    }

    // =============================================================================
    // 【Viewサマリー】postButton
    // 目的: 入力内容を投稿するボタン
    // 処理: submitPost()を非同期で呼び出す。写真が選択されていない場合は無効化
    // 戻り値: some View
    // =============================================================================
    private var postButton: some View {
        Button {
            Task { await submitPost() }
        } label: {
            Text(postsViewModel.isLoading ? "投稿中..." : "投稿する")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canPost ? Color.accentRed : Color.gray)
                .cornerRadius(16)
        }
        .disabled(!canPost || postsViewModel.isLoading)
        .padding(.bottom, 40)
    }

    // MARK: - Photo Section

    // =============================================================================
    // 【Viewサマリー】photoSection
    // 目的: 前面（front）と背面（back）の写真選択UIを表示する
    // 構成:
    //   - photoTile: 各面の写真表示/選択ボタン
    //   - 写真タップでMenu（再選択・編集・削除）を表示
    // 戻り値: some View
    // =============================================================================
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
        Menu {
            if image != nil {
                Button {
                    photoSourceTarget = target
                    editorReadyImage = image
                    showImageEditor = true
                } label: {
                    Label("スタンプを編集", systemImage: "pencil")
                }
            }
            Button {
                photoSourceTarget = target
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            } label: {
                Label("ライブラリから選択", systemImage: "photo")
            }
            Button {
                photoSourceTarget = target
                imagePickerSourceType = .camera
                showImagePicker = true
            } label: {
                Label("カメラで撮影", systemImage: "camera")
            }
        } label: {
            ZStack {
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipped()
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
                            .foregroundColor(.secondary)
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .background(Color.ecruBackground)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Child Section

    // =============================================================================
    // 【Viewサマリー】childSection
    // 目的: 投稿に紐づける子供を選択する水平スクロールセクションを表示する
    // 戻り値: some View
    // =============================================================================
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
                            Text(child.name.isEmpty ? "子供\(idx+1)" : child.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(selectedChildIndex == idx ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(selectedChildIndex == idx ? Color.accentRed : Color(.systemGray6))
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Info Section (region only, gender comes from child)

    // =============================================================================
    // 【Viewサマリー】infoSection
    // 目的: 投稿の地域情報を表示・選択するセクション
    // 戻り値: some View
    // =============================================================================
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel("地域")
                Spacer()
                Text("プロフィールから反映")
                    .font(.caption2)
                    .foregroundColor(.accentBlue)
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

    // =============================================================================
    // 【Viewサマリー】weatherSection
    // 目的: 天気・最高気温・最低気温の入力UIを表示する
    // 処理:
    //   - WeatherServiceで自動取得ボタン
    //   - 天気アイコンPicker（晴れ/曇り/雨など）
    //   - 気温テキスト入力
    // 戻り値: some View
    // =============================================================================
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
                            .foregroundColor(.accentBlue)
                    }
                }
            }

            // 地域選択（天気自動取得の基準地域）
            VStack(alignment: .leading, spacing: 4) {
                Text("地域")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("地域", selection: $selectedRegionIndex) {
                    ForEach(-1..<prefectures.count, id: \.self) { i in
                        Text(i == -1 ? "非公表" : prefectures[i]).tag(i)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .onChange(of: selectedRegionIndex) { _ in
                    if selectedRegionIndex >= 0 { fetchWeather() }
                }
            }

            HStack(spacing: 8) {
                ForEach(WeatherType.allCases) { w in
                    Button {
                        weatherType = w
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: w.sfSymbol)
                                .font(.system(size: 18))
                            Text(w.label).font(.system(size: 10))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(weatherType == w ? Color.accentBlue.opacity(0.12) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(weatherType == w ? Color.accentBlue : Color.clear, lineWidth: 1.5)
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
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Items Section

    // =============================================================================
    // 【Viewサマリー】itemsSection
    // 目的: 洋服アイテムの登録・編集・タグ付けUIを表示する
    // 構成:
    //   - 各アイテムのカテゴリ・ブランド・サイズ入力
    //   - アイテム追加/削除ボタン
    //   - 写真へのタグ配置ボタン
    // 戻り値: some View
    // =============================================================================
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
                        .foregroundColor(.accentGreen)
                        .font(.system(size: 22))
                }
            }

            ForEach(items.indices, id: \.self) { idx in
                ItemEntryRow(entry: $items[idx], onRemove: {
                    items.remove(at: idx)
                }, onTag: {
                    guard frontImage != nil || backImage != nil else {
                        showNoPhotoAlert = true
                        return
                    }
                    taggingSide = frontImage != nil ? "front" : "back"
                    taggingItemIndex = idx
                })
            }
        }
    }

    // MARK: - Tag Placement View

    // =============================================================================
    // 【Viewサマリー】tagPlacementView
    // 目的: アイテムタグを写真上に配置するためのインタラクティブView
    // 構成:
    //   - 編集対象の写真表示
    //   - タップ位置にタグ（ドット＋ラベル）を配置
    //   - 既存タグのタップで削除
    // 戻り値: some View
    // =============================================================================
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
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))

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
                                .background(taggingSide == side ? Color.accentBlue : Color(.systemGray5))
                                .foregroundColor(taggingSide == side ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            if let uiImg = img {
                GeometryReader { geo in
                    let imgW = geo.size.width
                    let imgH = uiImg.size.height / uiImg.size.width * imgW
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imgW, height: imgH)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { val in
                                        guard items.indices.contains(idx) else { return }
                                        let ratioX = max(0, min(1, val.location.x / imgW))
                                        let ratioY = max(0, min(1, val.location.y / imgH))
                                        items[idx].tagPosition = CGPoint(x: ratioX, y: ratioY)
                                        items[idx].tagSide = taggingSide
                                        print("[DEBUG] Tag saved: item=\(idx), side=\(taggingSide), pos=(\(ratioX), \(ratioY))")
                                        taggingItemIndex = nil
                                    }
                            )
                        ForEach(items.indices, id: \.self) { i in
                            tagDotOverlay(items: items, i: i, side: taggingSide,
                                          geoWidth: imgW, imgH: imgH)
                        }
                    }
                    .frame(width: imgW, height: imgH)
                }
                .frame(height: UIScreen.main.bounds.width * CGFloat(uiImg.size.height) / CGFloat(uiImg.size.width))
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
                // タグ風の背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                
                HStack(spacing: 2) {
                    // カテゴリアイコン
                    Image(systemName: categoryIcon(for: items[i].category))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentRed)
                    // 番号
                    Text("\(i + 1)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
            .fixedSize()
            .position(x: pos.x * geoWidth, y: pos.y * imgH)
        }
    }
    
    private func categoryIcon(for category: ItemCategory) -> String {
        switch category {
        case .tops:      return "tshirt.fill"
        case .bottoms:   return "shorts.fill"
        case .accessory: return "sparkles"
        case .outerwear: return "jacket.fill"
        case .shoes:     return "shoe.fill"
        case .bib:       return "bib.fill"
        case .other:     return "tag.fill"
        }
    }

    // 計算プロパティ: 投稿可能かどうか（少なくとも1枚の写真が必要）
    private var canPost: Bool { frontImage != nil || backImage != nil }

    // =============================================================================
    // 【Viewサマリー】sectionLabel
    // 目的: 各セクションのタイトルラベルを統一スタイルで表示するヘルパー
    // 引数:
    //   - text: String - セクションタイトル
    // 戻り値: some View
    // =============================================================================
    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .bold)).foregroundColor(.primary)
    }

    // =============================================================================
    // 【関数サマリー】applyProfileDefaults
    // 目的: ログイン中ユーザーのプロフィール情報を投稿フォームの初期値に反映する
    // 処理の流れ:
    //   1. authViewModel.currentUserから地域コードを取得してselectedRegionIndexに設定
    //   2. 子供の性別をselectedGenderに設定
    // 呼び出し元: bodyの.onAppear
    // =============================================================================
    private func applyProfileDefaults() {
        guard let user = authViewModel.currentUser else { return }
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        } else {
            selectedRegionIndex = -1
        }
        selectedGender = ChildGender(rawValue: user.child_gender) ?? .unselected
        if let draft = draftManager.pendingDraft {
            applyDraft(draft)
            draftManager.clearPendingDraft()
        } else {
            fetchWeather()
        }
    }

    // MARK: - Draft

    // =============================================================================
    // 【関数サマリー】saveDraft
    // 目的: 現在の入力内容をローカルに下書きとして保存する
    // 処理の流れ:
    //   1. 各画像をDocumentsディレクトリにJPEG保存
    //   2. PostDraftオブジェクトを生成
    //   3. DraftManager（UserDefaults）に保存
    //   4. 保存成功バナーを表示
    // =============================================================================
    private func saveDraft() {
        let draftId = editingDraftId ?? UUID().uuidString
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var frontPath: String? = nil
        var backPath: String? = nil
        if let img = frontImage, let data = img.jpegData(compressionQuality: 0.7) {
            let filename = "draft_front_\(draftId).jpg"
            try? data.write(to: docsURL.appendingPathComponent(filename))
            frontPath = filename
        }
        if let img = backImage, let data = img.jpegData(compressionQuality: 0.7) {
            let filename = "draft_back_\(draftId).jpg"
            try? data.write(to: docsURL.appendingPathComponent(filename))
            backPath = filename
        }
        let draftItems = items.map { entry in
            DraftItem(
                id: entry.id.uuidString,
                category: entry.category.rawValue,
                brandName: entry.brandName,
                selectedSize: entry.selectedSize
            )
        }
        let draft = PostDraft(
            id: draftId,
            description: description,
            regionIndex: selectedRegionIndex,
            weatherType: weatherType.rawValue,
            tempMax: tempMax,
            tempMin: tempMin,
            items: draftItems,
            savedAt: Date(),
            frontImagePath: frontPath,
            backImagePath: backPath
        )
        draftManager.saveDraft(draft)
        editingDraftId = draftId
        draftSaved = true
        withAnimation { showDraftSavedBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showDraftSavedBanner = false }
        }
    }

    // =============================================================================
    // 【関数サマリー】applyDraft
    // 目的: 保存された下書きデータをフォームに復元する
    // 引数:
    //   - draft: PostDraft - 復元対象の下書きデータ
    // 処理の流れ:
    //   1. 各フィールドに下書きデータを反映
    //   2. 保存済み画像ファイルをUIImageとして読み込む
    // =============================================================================
    private func applyDraft(_ draft: PostDraft) {
        editingDraftId = draft.id
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
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let path = draft.frontImagePath {
            frontImage = UIImage(contentsOfFile: docsURL.appendingPathComponent(path).path)
        }
        if let path = draft.backImagePath {
            backImage = UIImage(contentsOfFile: docsURL.appendingPathComponent(path).path)
        }
    }

    // =============================================================================
    // 【関数サマリー】fetchWeather
    // 目的: 選択中の地域の現在の天気・気温を自動取得する
    // 処理の流れ:
    //   1. 選択中の地域コードでWeatherService.fetchCurrentWeatherを呼び出し
    //   2. 結果をweatherType・tempMax・tempMinに反映
    //   3. エラー時はエラーメッセージを設定
    // =============================================================================
    private func fetchWeather() {
        guard selectedRegionIndex >= 0 else {
            isFetchingWeather = false
            return
        }
        let code = String(format: "%02d", selectedRegionIndex + 1)
        isFetchingWeather = true
        Task {
            let result = await WeatherService.shared.fetch(regionCode: code)
            await MainActor.run {
                if let result = result {
                    tempMax = String(format: "%.0f", result.tempMax)
                    tempMin = String(format: "%.0f", result.tempMin)
                    weatherType = WeatherType(rawValue: result.weatherType) ?? .sunny
                }
                isFetchingWeather = false
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】submitPost
    // 目的: 入力内容をもとに投稿を作成し、FirestoreとStorageに保存する
    // 処理の流れ:
    //   1. 子供情報・写真URL・アイテム情報を収集
    //   2. postsViewModel.uploadPost()を呼び出して投稿作成
    //   3. 成功時はダイアログを閉じてフォームをリセット
    //   4. 失敗時はエラーアラートを表示
    // =============================================================================
    private func submitPost() async {
        guard let user = authViewModel.currentUser else { return }

        // 子供が登録されている場合、選択中の子供情報を使う
        let selectedChild: ChildProfile? = children.indices.contains(selectedChildIndex) ? children[selectedChildIndex] : nil
        let effectiveBirthday = selectedChild?.birthday ?? user.child_birthday
        let effectiveGender = selectedChild.map { ChildGender(rawValue: $0.gender)?.rawValue ?? selectedGender.rawValue } ?? selectedGender.rawValue

        let regionCode = selectedRegionIndex >= 0 ? String(format: "%02d", selectedRegionIndex + 1) : "00"
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
            let tag = PostItemTag(
                item_index: filteredIdx,
                x_ratio: Double(pos.x),
                y_ratio: Double(pos.y),
                image_side: items[idx].tagSide
            )
            print("[DEBUG] PostItemTag created: item_index=\(tag.item_index), side=\(tag.image_side)")
            return tag
        }
        let collectedTags: [PostItemTag] = tags
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
            // 編集中の下書きがあれば、画像ファイルも含めて完全に削除
            if let draftId = editingDraftId {
                draftManager.deleteDraftById(draftId)
            }
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

    @State private var showBrandSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.category.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentBlue.opacity(0.1))
                    .foregroundColor(.accentBlue)
                    .cornerRadius(10)
                Spacer()
                // Tag button
                Button(action: onTag) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.tagPosition != nil ? "tag.fill" : "tag")
                            .font(.system(size: 11, weight: .medium))
                        Text("タグ付け")
                            .font(.system(size: 12, weight: .medium))
                        if entry.tagPosition != nil {
                            Text(entry.tagSide == "front" ? "F" : "B")
                                .font(.system(size: 10, weight: .bold))
                        }
                    }
                    .foregroundColor(entry.tagPosition != nil ? .white : .accentBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(entry.tagPosition != nil ? Color.accentBlue : Color.accentBlue.opacity(0.08))
                    .cornerRadius(10)
                }
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            HStack(spacing: 8) {
                // ブランド入力フィールド
                HStack(spacing: 0) {
                    TextField("ブランド名（例: UNIQLO）", text: $entry.brandName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    Button {
                        showBrandSearch = true
                    } label: {
                        Text("検索")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color.accentBlue)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 4)
                }
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4), lineWidth: 1))
                .frame(maxWidth: .infinity)

                Picker("サイズ", selection: $entry.selectedSize) {
                    ForEach(clothingSizes, id: \.self) { s in
                        Text(sizeLabel(s)).tag(s)
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
        .sheet(isPresented: $showBrandSearch) {
            BrandSearchSheet(selectedBrand: $entry.brandName)
        }
    }
}

// MARK: - BrandSearchSheet（メルカリ風ブランド検索）

struct BrandSearchSheet: View {
    @Binding var selectedBrand: String
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredBrands: [BrandEntry] {
        filterBrands(allBrands, query: query)
    }

    // 入力されたブランド名をallBrands内の正式名称に正規化して返す
    private func canonicalBrandName(for input: String) -> String {
        let normalizedInput = normalizeForSearch(input)
        // マッチする正式名称があればそれを返す
        if let match = allBrands.first(where: { normalizeForSearch($0.name) == normalizedInput }) {
            return match.name
        }
        // 読み仮名完全一致も探す
        if let readingMatch = allBrands.first(where: { $0.reading == normalizedInput }) {
            return readingMatch.name
        }
        // 部分一致も探す（「ユニクロ」→「UNIQLO」など）
        if let partial = allBrands.first(where: {
            normalizeForSearch($0.name).contains(normalizedInput) ||
            $0.reading.contains(normalizedInput) ||
            normalizedInput.contains(normalizeForSearch($0.name)) ||
            normalizedInput.contains($0.reading)
        }) {
            return partial.name
        }
        return input
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("ブランド名を検索（ふりがな可）", text: $query)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 直接入力ボタン（検索結果にない場合）— 正規化して正式名称に統一
                if !query.isEmpty && !filteredBrands.contains(where: { $0.name.lowercased() == query.lowercased() }) {
                    let canonicalBrand = canonicalBrandName(for: query)
                    Button {
                        selectedBrand = canonicalBrand
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentBlue)
                            Text("「\(canonicalBrand)」を使用する")
                                .font(.system(size: 14))
                                .foregroundColor(.accentBlue)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.accentBlue.opacity(0.06))
                    }
                    .buttonStyle(.plain)
                    Divider()
                }

                // ブランドリスト
                List {
                    if filteredBrands.isEmpty {
                        Text("該当するブランドが見つかりません")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 20)
                            .listRowBackground(Color.clear)
                    } else {
                        Section(header: Text(query.isEmpty ? "人気ブランド" : "検索結果").font(.caption)) {
                            ForEach(filteredBrands) { brand in
                                Button {
                                    selectedBrand = brand.name
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(brand.name)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                        Text(brand.reading)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                        Spacer()
                                        if selectedBrand == brand.name {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.accentBlue)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("ブランドを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { isSearchFocused = true }
        }
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
    var scale: CGFloat = 2.5
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
        case .circle:   return .accentRed
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
    @State private var selectedKind: StampKind? = nil
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
    // 説明: 写真編集画面で使用するスタンプ選択パレット

    // =============================================================================
    // 【Viewサマリー】stampPalette
    // 目的: SF Symbolスタンプと画像スタンプを横スクロールで表示し、選択状態を管理する
    // 戻り値: some View
    // =============================================================================
    private var stampPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // 画像スタンプ（先に表示）— StampImages/ に画像を追加しstampImageNamesに追記すると自動で出現
                if !stampImageNames.isEmpty {
                    ForEach(stampImageNames, id: \.self) { name in
                        let kind = StampKind.image(name)
                        Button {
                            selectedKind = kind
                        } label: {
                            Image(name)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .background(selectedKind == kind ? Color(UIColor.systemGray4).opacity(0.6) : Color(.systemGray6))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedKind == kind ? Color.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                )
                        }
                    }
                    Divider().frame(height: 32)
                }
                // SF Symbol スタンプ（後に表示）
                ForEach(StampSymbol.allCases) { sym in
                    let kind = StampKind.symbol(sym)
                    Button {
                        selectedKind = kind
                    } label: {
                        Image(systemName: sym.rawValue)
                            .font(.system(size: 24))
                            .foregroundColor(sym.color)
                            .frame(width: 44, height: 44)
                            .background(selectedKind == kind ? Color(UIColor.systemGray4).opacity(0.6) : Color(.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedKind == kind ? Color.primary.opacity(0.5) : Color.clear, lineWidth: 1.5)
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
    // 説明: 写真上にスタンプを配置・編集するキャンバスView

    // =============================================================================
    // 【Viewサマリー】canvas
    // 目的: 写真を表示し、タップ・ドラッグでスタンプの配置・移動・拡縮を可能にする
    // 戻り値: some View
    // =============================================================================
    private var canvas: some View {
        GeometryReader { geo in
            let imgW = image.size.width
            let imgH = image.size.height
            let fitScale = min(geo.size.width / imgW, geo.size.height / imgH)
            let dispW = imgW * fitScale
            let dispH = imgH * fitScale
            let offsetX = (geo.size.width - dispW) / 2
            let offsetY = (geo.size.height - dispH) / 2

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: dispW, height: dispH)
                    .onAppear {
                        canvasSize = CGSize(width: dispW, height: dispH)
                        canvasOffset = CGPoint(x: offsetX, y: offsetY)
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { val in
                                guard let kind = selectedKind else { return }
                                // ZStack(alignment: .topLeft) なので座標をそのまま使う
                                let stampX = val.location.x - offsetX
                                let stampY = val.location.y - offsetY
                                let position = CGPoint(
                                    x: max(0, min(stampX, dispW)),
                                    y: max(0, min(stampY, dispH))
                                )
                                let stamp = PlacedStamp(kind: kind, position: position)
                                stampItems.append(stamp)
                                history.append(.addStamp(stamp))
                                activeStampId = stamp.id
                                selectedKind = nil
                            }
                    )
                    .offset(x: offsetX, y: offsetY)
                ForEach($stampItems) { $stamp in
                    StampView(stamp: $stamp,
                              canvasOffset: canvasOffset,
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
    // 説明: スタンプ編集画面の操作ヒントテキスト

    // =============================================================================
    // 【Viewサマリー】hintText
    // 目的: スタンプ編集画面の操作ガイドを表示する
    // 戻り値: some View
    // =============================================================================
    private var hintText: some View {
        Text(selectedKind != nil ? "タップで配置" : "スタンプを選択 • ハンドル上下ドラッグで拡縮 • ダブルタップで削除")
            .font(.caption)
            .foregroundColor(selectedKind != nil ? .accentRed : .secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
    }

    // MARK: - Undo
    // 説明: スタンプ操作のundo機能

    // =============================================================================
    // 【関数サマリー】performUndo
    // 目的: 最後に行ったスタンプ操作（追加・削除・移動・拡縮）を元に戻す
    // 処理の流れ:
    //   1. history配列から最後の操作を取り出す
    //   2. 操作の種類に応じてstampItemsを修正
    // =============================================================================
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
    // 説明: 配置したスタンプを合成して最終画像を生成

    // =============================================================================
    // 【関数サマリー】renderFinalImage
    // 目的: スタンプを元の写真に合成して、編集後のUIImageを生成する
    // 戻り値: UIImage - スタンプ合成済みの最終画像
    // 処理の流れ:
    //   1. キャンバス座標系から画像座標系へ変換
    //   2. UIGraphicsImageRendererで元画像に各スタンプを描画
    // =============================================================================
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
    let canvasOffset: CGPoint
    let isActive: Bool
    let onTap: () -> Void
    let onRemove: () -> Void

    private let baseSize: CGFloat = 44

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var rotationAngle: Angle = .zero
    @State private var liveScaleFactor: CGFloat = 1.0

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
        .scaleEffect(stamp.scale * liveScaleFactor)
        .rotationEffect(stamp.rotation + rotationAngle)
        .shadow(color: .black.opacity(0.2), radius: 2)
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                    .frame(width: baseSize * stamp.scale * liveScaleFactor + 12,
                           height: baseSize * stamp.scale * liveScaleFactor + 12)
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.black.opacity(0.72))
                            .clipShape(Circle())
                            .offset(x: 4, y: -4)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { val in
                                        let factor = 1.0 + (-val.translation.height / 80.0)
                                        liveScaleFactor = max(0.1, factor)
                                    }
                                    .onEnded { val in
                                        stamp.scale = max(0.2, min(6.0, stamp.scale * liveScaleFactor))
                                        liveScaleFactor = 1.0
                                    }
                            )
                    }
                    Spacer()
                }
                .frame(width: baseSize * stamp.scale * liveScaleFactor + 12,
                       height: baseSize * stamp.scale * liveScaleFactor + 12)
            }
        }
        .position(
            x: stamp.position.x + canvasOffset.x + dragOffset.width,
            y: stamp.position.y + canvasOffset.y + dragOffset.height
        )
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .updating($dragOffset) { val, state, _ in state = val.translation }
                    .onEnded { val in
                        stamp.position.x += val.translation.width
                        stamp.position.y += val.translation.height
                    },
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

// MARK: - TagPlacementView
// 説明: アイテムの写真上の位置をフルスクリーンで選択する画面

struct TagPlacementView: View {
    @Binding var items: [NewItemEntry]
    let itemIndex: Int
    @Binding var taggingSide: String
    let frontImage: UIImage?
    let backImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 写真切り替えタブ
                HStack(spacing: 12) {
                    ForEach(["front", "back"], id: \.self) { side in
                        let hasImg = side == "front" ? frontImage != nil : backImage != nil
                        if hasImg {
                            Button {
                                taggingSide = side
                            } label: {
                                Text(side == "front" ? "フロント" : "バック")
                                    .font(.system(size: 14, weight: .medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(taggingSide == side ? Color.accentBlue : Color(.systemGray5))
                                    .foregroundColor(taggingSide == side ? .white : .primary)
                                    .cornerRadius(10)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

                // 写真表示＋タグ付けエリア
                GeometryReader { geo in
                    let uiImg = taggingSide == "front" ? frontImage : backImage
                    if let uiImg = uiImg {
                        let imgW = geo.size.width
                        let imgH = uiImg.size.height / uiImg.size.width * imgW
                        let maxH = min(imgH, geo.size.height)
                        let scale = min(1, maxH / imgH)
                        let dispW = imgW * scale
                        let dispH = imgH * scale
                        let offsetX = (geo.size.width - dispW) / 2
                        let offsetY = (geo.size.height - dispH) / 2

                        ZStack(alignment: .topLeading) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: dispW, height: dispH)
                                .offset(x: offsetX, y: offsetY)
                                .contentShape(Rectangle())
                                .simultaneousGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onEnded { val in
                                            guard items.indices.contains(itemIndex) else { return }
                                            let tapX = val.location.x - offsetX
                                            let tapY = val.location.y - offsetY
                                            let ratioX = max(0, min(1, tapX / dispW))
                                            let ratioY = max(0, min(1, tapY / dispH))
                                            items[itemIndex].tagPosition = CGPoint(x: ratioX, y: ratioY)
                                            items[itemIndex].tagSide = taggingSide
                                            dismiss()
                                        }
                                )

                            // 既存タグの表示
                            ForEach(items.indices, id: \.self) { i in
                                if let pos = items[i].tagPosition,
                                   items[i].tagSide == taggingSide {
                                    tagOverlay(items: items, i: i)
                                        .position(
                                            x: offsetX + pos.x * dispW,
                                            y: offsetY + pos.y * dispH
                                        )
                                }
                            }
                        }
                    } else {
                        Text("写真を先に追加してください")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("タグを付ける場所をタップ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func tagOverlay(items: [NewItemEntry], i: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(i == itemIndex ? Color.accentBlue : Color.white)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

            HStack(spacing: 2) {
                Image(systemName: categoryIcon(for: items[i].category))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(i == itemIndex ? .white : .accentRed)
                Text("\(i + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(i == itemIndex ? .white : .primary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        }
        .fixedSize()
    }

    private func categoryIcon(for category: ItemCategory) -> String {
        switch category {
        case .tops:      return "tshirt.fill"
        case .bottoms:   return "shorts.fill"
        case .accessory: return "sparkles"
        case .outerwear: return "jacket.fill"
        case .shoes:     return "shoe.fill"
        case .bib:       return "bib.fill"
        case .other:     return "tag.fill"
        }
    }
}

