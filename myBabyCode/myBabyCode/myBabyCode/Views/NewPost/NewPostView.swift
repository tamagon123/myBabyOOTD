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

    // === カレンダー連携 ===
    var calendarDate: Date? = nil          // カレンダーから開いた場合の指定日付
    var isFromCalendar: Bool { calendarDate != nil }  // カレンダーからの投稿かどうか

    // === 編集モード ===
    var editingPost: Post? = nil           // 編集対象の投稿（nilなら新規投稿）
    var isEditMode: Bool { editingPost != nil }

    // === 写真関連 ===
    @State private var frontImage: UIImage?              // 正面写真（スタンプ合成済み）
    @State private var backImage: UIImage?               // 背面写真（スタンプ合成済み）
    @State private var originalFrontImage: UIImage?      // オリジナル画像（スタンプなし）
    @State private var originalBackImage: UIImage?       // オリジナル画像（スタンプなし）
    @State private var photoSourceTarget: PhotoTarget = .front  // 現在選択中の写真対象（front/back）
    @State private var showPhotoSourceSheet = false      // 写真ソース選択（カメラ/ライブラリ）シート
    @State private var showImagePicker = false           // UIImagePickerController表示フラグ
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var editingImage: UIImage?            // 編集中の画像（スタンプ編集画面へ渡す）
    @State private var showImageEditor = false           // スタンプ編集画面表示フラグ
    @State private var editorReadyImage: UIImage?        // 編集完了後の画像
    @State private var showEditConfirm = false           // 編集確認ダイアログ
    @State private var showPhotoActionSheet = false      // 写真再選択/編集アクションシート
    @State private var showFrontPhotoPopover = false     // フロント写真選択ポップオーバー
    @State private var showBackPhotoPopover = false      // バック写真選択ポップオーバー

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
    @State private var isSubmitting: Bool = false         // 投稿中フラグ（連打防止）

    // === 子供選択 ===
    @State private var selectedChildIndex: Int = 0        // 選択中の子供インデックス

    // === 月齢カスタマイズ ===
    @State private var useCustomAge: Bool = false          // カスタム月齢を使用するか
    @State private var customAgeYears: Int = 0             // カスタム年齢（年）
    @State private var customAgeMonths: Int = 0            // カスタム年齢（月）

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
    @State private var showDraftCloseAlert = false        // 下書き保存後「閉じますか？」アラート

    // === 編集モード用: 既存写真の削除フラグ ===
    @State private var removedFrontImage = false          // 既存フロント画像を削除したか
    @State private var removedBackImage = false           // 既存バック画像を削除したか

    // 計算プロパティ: ログイン中ユーザーの子供リスト（プロフィール設定時に登録）
    private var children: [ChildProfile] { authViewModel.currentUser?.children ?? [] }
    
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    // 変更があるかどうか（閉じる時の確認用）
    private var hasChanges: Bool {
        frontImage != nil || backImage != nil || !items.isEmpty || !description.isEmpty
    }

    // 編集モード用: 新しく選択された写真（既存URLと区別するため）
    @State private var newFrontImage: UIImage? = nil
    @State private var newBackImage: UIImage? = nil

    // 下書き保存ボタンを活性にする条件: 入力あり かつ 未保存
    private var canSaveDraft: Bool {
        let hasInput = frontImage != nil
            || backImage != nil
            || items.contains(where: { !$0.brandName.trimmingCharacters(in: .whitespaces).isEmpty })
            || !description.trimmingCharacters(in: .whitespaces).isEmpty
        return hasInput && !draftSaved
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
            if isIPad {
                iPadContent
            } else {
                scrollContent
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - iPad Layout (redesigned)
    //
    // 説明:
    //   iPadでは2カラムレイアウトを採用。
    //   左ペインに正方形の写真プレビューカード（Popoverで編集/再選択）、
    //   右ペインにカード化されたフォーム（子供・天気・ポイント・アイテム）を配置。
    //   アクションボタンは各ペイン下部に配置し、ナビバーには「閉じる」のみ残す。
    // =============================================================================

    // MARK: - iPad Left Pane (写真選択エリア)

    private var iPadLeftPane: some View {
        ScrollView {
            VStack(spacing: 20) {
                iPadPhotoCard(title: "フロント", image: frontImage, target: .front)
                iPadPhotoCard(title: "バック", image: backImage, target: .back)
                Text("どちらか1枚以上必須")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(24)
        }
        .background(Color(.secondarySystemBackground))
        .frame(maxWidth: .infinity)
    }

    // MARK: - iPad Photo Card (正方形・Popover付き)
    // 説明: フロント/バックの写真プレビューを表示する正方形カード。
    //       タップでPopover（ライブラリ/カメラ/スタンプ編集）を表示。
    //       未選択時は赤枠プレースホルダー、選択済みはscaledToFitで全体表示。
    @ViewBuilder
    private func iPadPhotoCard(title: String, image: UIImage?, target: PhotoTarget) -> some View {
        let showPopover = target == .front ? $showFrontPhotoPopover : $showBackPhotoPopover
        Button {
            photoSourceTarget = target
            if target == .front { showFrontPhotoPopover = true } else { showBackPhotoPopover = true }
        } label: {
            ZStack {
                if let img = image {
                    Color.black
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack {
                        Spacer()
                        HStack {
                            Text(title)
                                .font(.appFont(.bold, size: 14))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.55)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemBackground))
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.accentRed.opacity(0.25), lineWidth: 1.5)
                    VStack(spacing: 14) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 42, weight: .light))
                            .foregroundColor(Color.accentRed.opacity(0.85))
                        Text(title)
                            .font(.appFont(.bold, size: 17))
                            .foregroundColor(.primary)
                        Text("タップして追加")
                            .font(.appFont(.regular, size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .cornerRadius(20)
            .shadow(color: .black.opacity(image != nil ? 0.15 : 0.06), radius: 12, y: 4)
            .clipped()
        }
        .buttonStyle(.plain)
        .popover(isPresented: showPopover, arrowEdge: .trailing) {
            iPadPhotoPopoverContent(image: image, target: target)
                .frame(minWidth: 220, minHeight: image != nil ? 210 : 110)
        }
        .overlay(alignment: .topTrailing) {
            if image != nil {
                Button {
                    if target == .front {
                        frontImage = nil; originalFrontImage = nil; newFrontImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "front" }
                    } else {
                        backImage = nil; originalBackImage = nil; newBackImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "back" }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .padding(10)
            }
        }
    }

    // MARK: - iPad Photo Popover Content
    // 説明: 写真カードタップ時に表示するPopoverの内容。
    //       写真あり→「ライブラリ」「カメラ」「スタンプ編集」、なし→前2つ。
    @ViewBuilder
    private func iPadPhotoPopoverContent(image: UIImage?, target: PhotoTarget) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if image != nil {
                photoPopoverButton(label: "ライブラリから選択", icon: "photo") {
                    imagePickerSourceType = .photoLibrary; showImagePicker = true
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
                Divider()
                photoPopoverButton(label: "カメラで撮影", icon: "camera") {
                    imagePickerSourceType = .camera; showImagePicker = true
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
                Divider()
                photoPopoverButton(label: "スタンプを編集", icon: "pencil") {
                    editorReadyImage = target == .front ? originalFrontImage : originalBackImage
                    showImageEditor = true
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
                Divider()
                photoPopoverButton(label: "写真を削除", icon: "trash") {
                    if target == .front {
                        frontImage = nil; originalFrontImage = nil; newFrontImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "front" }
                    } else {
                        backImage = nil; originalBackImage = nil; newBackImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "back" }
                    }
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
            } else {
                photoPopoverButton(label: "ライブラリから選択", icon: "photo") {
                    imagePickerSourceType = .photoLibrary; showImagePicker = true
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
                Divider()
                photoPopoverButton(label: "カメラで撮影", icon: "camera") {
                    imagePickerSourceType = .camera; showImagePicker = true
                    if target == .front { showFrontPhotoPopover = false } else { showBackPhotoPopover = false }
                }
            }
        }
        .frame(width: 220)
    }

    // MARK: - iPad Photo Popover Button Helper
    @ViewBuilder
    private func photoPopoverButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.appFont(.regular, size: 15))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - iPad Right Pane (フォーム入力エリア)

    private var iPadRightPane: some View {
        ScrollView {
            VStack(spacing: 16) {
                iPadFormCard {
                    childSection
                }
                iPadFormCard {
                    itemsSection
                }
                iPadFormCard {
                    descriptionSection
                }
                iPadFormCard {
                    weatherSection
                }
                iPadActionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - iPad Form Card (角丸・ドロップシャドウのカードラッパー)
    @ViewBuilder
    private func iPadFormCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }

    // MARK: - iPad Action Buttons (投稿・下書き保存)
    // 説明: 右ペイン下部に配置するアクションボタン群。
    //       「投稿する」は赤背景でフルワイド、「下書きとして保存」はサブトーン。
    private var iPadActionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await submitPost() }
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.85)
                    }
                    Text(isSubmitting ? "投稿中..." : "投稿する")
                        .font(.appFont(.bold, size: 17))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(canPost && !isSubmitting ? Color.accentRed : Color.gray)
                .cornerRadius(16)
            }
            .disabled(!canPost || isSubmitting || postsViewModel.isLoading)

            if !isEditMode {
                Button {
                    saveDraft()
                    showDraftCloseAlert = true
                } label: {
                    Label("下書きとして保存", systemImage: "square.and.arrow.down")
                        .font(.appFont(.medium, size: 15))
                        .foregroundColor(canSaveDraft ? Color.accentRed : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSaveDraft ? Color.accentRed.opacity(0.07) : Color(.systemGray5))
                        .cornerRadius(14)
                }
                .disabled(!canSaveDraft)
            }
        }
    }

    // MARK: - iPad Layout Body (HStackコンテナ)

    private var iPadLayoutBody: some View {
        HStack(spacing: 0) {
            iPadLeftPane
            Divider()
            iPadRightPane
        }
        .background(Color(.systemBackground))
    }

    // MARK: - iPad Content (Body＋ツールバー＋アラート)

    private var iPadContent: some View {
        iPadLayoutBody
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { dismissKeyboard() }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        if isEditMode {
                            showDiscardAlert = true
                        } else if canSaveDraft {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .overlay(alignment: .top) {
                if showDraftSavedBanner {
                    Text("下書きを保存しました")
                        .font(.appFont(.medium, size: 14))
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
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { applyProfileDefaults() }
            .onChange(of: frontImage) { _ in draftSaved = false }
            .onChange(of: backImage) { _ in draftSaved = false }
            .onChange(of: description) { _ in draftSaved = false }
            .onChange(of: items) { _ in draftSaved = false }
            .alert(isEditMode ? "変更を破棄しますか？" : "下書きを保存しますか？", isPresented: $showDiscardAlert) {
                if isEditMode {
                    Button("変更せずに閉じる", role: .destructive) { dismiss() }
                    Button("キャンセル", role: .cancel) {}
                } else {
                    Button("保存する") { saveDraft(); dismiss() }
                    Button("保存しない", role: .destructive) { dismiss() }
                    Button("キャンセル", role: .cancel) {}
                }
            } message: { Text(isEditMode ? "編集内容は保存されません。" : "編集内容を下書きとして保存できます。") }
            .alert("このまま閉じますか？", isPresented: $showDraftCloseAlert) {
                Button("閉じる") { dismiss() }
                Button("続ける", role: .cancel) { draftSaved = false }
            } message: { Text("下書きを保存しました。投稿画面を閉じますか？") }
            .alert(isEditMode ? "更新完了！" : "投稿完了！", isPresented: $showSuccess) {
                Button("OK") {
                    Task {
                        await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                        await postsViewModel.fetchLikedPosts()
                    }
                    dismiss()
                }
            } message: { Text(isEditMode ? "投稿内容を更新しました" : "コーディネートを共有しました") }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: { Text(postsViewModel.errorMessage ?? "不明なエラーが発生しました。") }
            .alert("写真を選択してください", isPresented: $showNoPhotoAlert) {
                Button("OK") {}
            } message: { Text("タグ付けを行う前に、コーディネートの写真を撮影または選択してください。") }
            .confirmationDialog("写真を選択", isPresented: $showPhotoSourceSheet, titleVisibility: .visible) {
                Button("カメラで撮影") { imagePickerSourceType = .camera; showImagePicker = true }
                Button("ライブラリから選択") { imagePickerSourceType = .photoLibrary; showImagePicker = true }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker, onDismiss: {
                if editingImage != nil { showEditConfirm = true }
            }) {
                ImagePickerView(sourceType: imagePickerSourceType) { img in editingImage = img }
            }
            .confirmationDialog("この写真を編集しますか？", isPresented: $showEditConfirm, titleVisibility: .visible) {
                Button("編集する（スタンプ）") {
                    if photoSourceTarget == .front { originalFrontImage = editingImage } else { originalBackImage = editingImage }
                    editorReadyImage = editingImage; editingImage = nil; showImageEditor = true
                }
                Button("そのまま使う") {
                    if photoSourceTarget == .front {
                        originalFrontImage = editingImage; frontImage = editingImage
                        if isEditMode { newFrontImage = editingImage }
                    } else {
                        originalBackImage = editingImage; backImage = editingImage
                        if isEditMode { newBackImage = editingImage }
                    }
                    editingImage = nil
                }
                Button("キャンセル", role: .cancel) { editingImage = nil }
            }
            .sheet(isPresented: $showImageEditor, onDismiss: { editorReadyImage = nil }) {
                if let img = editorReadyImage {
                    let side = photoSourceTarget == .front ? "front" : "back"
                    let existing = postsViewModel.pendingStamps.filter { $0.image_side == side }
                    PhotoEditorView(
                        image: img, imageSide: side,
                        onDone: { edited in
                            if photoSourceTarget == .front {
                                frontImage = edited
                                if isEditMode { newFrontImage = edited }
                            } else {
                                backImage = edited
                                if isEditMode { newBackImage = edited }
                            }
                        },
                        onSaveStamps: { stamps in
                            postsViewModel.pendingStamps.removeAll { $0.image_side == side }
                            postsViewModel.pendingStamps.append(contentsOf: stamps)
                        },
                        existingStamps: existing
                    )
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { taggingItemIndex != nil },
                set: { if !$0 { taggingItemIndex = nil } }
            )) {
                if let idx = taggingItemIndex {
                    TagPlacementView(items: $items, itemIndex: idx, taggingSide: $taggingSide, frontImage: frontImage, backImage: backImage)
                }
            }
    }

    private var scrollContent: some View {
        baseContent
            .confirmationDialog("写真を選択", isPresented: $showPhotoSourceSheet, titleVisibility: .visible) {
                Button("カメラで撮影") { imagePickerSourceType = .camera; showImagePicker = true }
                Button("ライブラリから選択") { imagePickerSourceType = .photoLibrary; showImagePicker = true }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker, onDismiss: {
                if editingImage != nil { showEditConfirm = true }
            }) {
                ImagePickerView(sourceType: imagePickerSourceType) { img in editingImage = img }
            }
            .confirmationDialog("この写真を編集しますか？", isPresented: $showEditConfirm, titleVisibility: .visible) {
                Button("編集する（スタンプ）") {
                    if photoSourceTarget == .front { originalFrontImage = editingImage } else { originalBackImage = editingImage }
                    editorReadyImage = editingImage; editingImage = nil; showImageEditor = true
                }
                Button("そのまま使う") {
                    if photoSourceTarget == .front {
                        originalFrontImage = editingImage; frontImage = editingImage
                        if isEditMode { newFrontImage = editingImage }
                    } else {
                        originalBackImage = editingImage; backImage = editingImage
                        if isEditMode { newBackImage = editingImage }
                    }
                    editingImage = nil
                }
                Button("キャンセル", role: .cancel) { editingImage = nil }
            }
            .sheet(isPresented: $showImageEditor, onDismiss: { editorReadyImage = nil }) {
                if let img = editorReadyImage {
                    let side = photoSourceTarget == .front ? "front" : "back"
                    let existing = postsViewModel.pendingStamps.filter { $0.image_side == side }
                    PhotoEditorView(
                        image: img, imageSide: side,
                        onDone: { edited in
                            if photoSourceTarget == .front {
                                frontImage = edited
                                if isEditMode { newFrontImage = edited }
                            } else {
                                backImage = edited
                                if isEditMode { newBackImage = edited }
                            }
                        },
                        onSaveStamps: { stamps in
                            postsViewModel.pendingStamps.removeAll { $0.image_side == side }
                            postsViewModel.pendingStamps.append(contentsOf: stamps)
                        },
                        existingStamps: existing
                    )
                }
            }
            .alert(isEditMode ? "更新完了！" : "投稿完了！", isPresented: $showSuccess) {
                Button("OK") {
                    Task {
                        await postsViewModel.fetchPosts(user: authViewModel.currentUser)
                        await postsViewModel.fetchLikedPosts()
                    }
                    dismiss()
                }
            } message: { Text(isEditMode ? "投稿内容を更新しました" : "コーディネートを共有しました") }
            .alert("エラー", isPresented: $showError) {
                Button("OK") {}
            } message: { Text(postsViewModel.errorMessage ?? "不明なエラーが発生しました。") }
            .alert("写真を選択してください", isPresented: $showNoPhotoAlert) {
                Button("OK") {}
            } message: { Text("タグ付けを行う前に、コーディネートの写真を撑影または選択してください。") }
            .fullScreenCover(isPresented: Binding(
                get: { taggingItemIndex != nil },
                set: { if !$0 { taggingItemIndex = nil } }
            )) {
                if let idx = taggingItemIndex {
                    TagPlacementView(items: $items, itemIndex: idx, taggingSide: $taggingSide, frontImage: frontImage, backImage: backImage)
                }
            }
    }

    private var baseContent: some View {
        ScrollView {
            mainForm.frame(maxWidth: .infinity)
        }
        .clipped()
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { dismissKeyboard() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    if isEditMode {
                        showDiscardAlert = true
                    } else if canSaveDraft {
                        showDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showDraftSavedBanner {
                Text("下書きを保存しました")
                    .font(.appFont(.medium, size: 14))
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
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applyProfileDefaults() }
        .onChange(of: frontImage) { _ in draftSaved = false }
        .onChange(of: backImage) { _ in draftSaved = false }
        .onChange(of: description) { _ in draftSaved = false }
        .onChange(of: items) { _ in draftSaved = false }
        .alert(isEditMode ? "変更を破棄しますか？" : "下書きを保存しますか？", isPresented: $showDiscardAlert) {
            if isEditMode {
                Button("変更せずに閉じる", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            } else {
                Button("保存する") { saveDraft(); dismiss() }
                Button("保存しない", role: .destructive) { dismiss() }
                Button("キャンセル", role: .cancel) {}
            }
        } message: { Text(isEditMode ? "編集内容は保存されません。" : "編集内容を下書きとして保存できます。") }
        .alert("このまま閉じますか？", isPresented: $showDraftCloseAlert) {
            Button("閉じる") { dismiss() }
            Button("続ける", role: .cancel) { draftSaved = false }
        } message: { Text("下書きを保存しました。投稿画面を閉じますか？") }
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
            childSection
                .padding(.horizontal, 20)
            Divider().padding(.horizontal, 20)
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
    // 目的: 投稿の説明文入力（通常：服装のポイント、カレンダー：日記コメント）
    // 戻り値: some View
    // =============================================================================
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // カレンダー投稿の場合は「日記コメント」、通常投稿は「服装のポイント」
            sectionLabel(isFromCalendar ? "日記コメント" : "服装のポイント")
            if #available(iOS 16.0, *) {
                TextField(
                    isFromCalendar ? "例：今日は公園に行きました" : "例：気温が上がったので半袖デビュー！",
                    text: $description,
                    axis: .vertical
                )
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
        Group {
            if !isEditMode {
                Button {
                    saveDraft()
                    showDraftCloseAlert = true
                } label: {
                    Label("下書きとして保存", systemImage: "square.and.arrow.down")
                        .font(.appFont(.medium, size: 15))
                        .foregroundColor(canSaveDraft ? Color.accentGreen : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSaveDraft ? Color.accentGreen.opacity(0.1) : Color(.systemGray5))
                        .cornerRadius(14)
                }
                .disabled(!canSaveDraft)
            }
        }
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
            Text(isSubmitting ? (isEditMode ? "更新中..." : "投稿中...") : (isEditMode ? "更新する" : "投稿する"))
                .font(.appFont(.bold, size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canPost && !isSubmitting ? Color.accentRed : Color.gray)
                .cornerRadius(16)
        }
        .disabled(!canPost || isSubmitting || postsViewModel.isLoading)
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
        let showDialog = target == .front ? $showFrontPhotoPopover : $showBackPhotoPopover
        ZStack(alignment: .topTrailing) {
            Button {
                photoSourceTarget = target
                if target == .front { showFrontPhotoPopover = true } else { showBackPhotoPopover = true }
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
                                    .font(.appFont(.regular, size: 22))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                    .padding(6)
                            }
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.appFont(.regular, size: 28))
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
            .confirmationDialog(title, isPresented: showDialog, titleVisibility: .visible) {
                if image != nil {
                    Button("スタンプを編集") {
                        editorReadyImage = target == .front ? originalFrontImage : originalBackImage
                        showImageEditor = true
                    }
                    Button("写真を削除", role: .destructive) {
                        if target == .front {
                            frontImage = nil; originalFrontImage = nil; newFrontImage = nil
                            postsViewModel.pendingStamps.removeAll { $0.image_side == "front" }
                        } else {
                            backImage = nil; originalBackImage = nil; newBackImage = nil
                            postsViewModel.pendingStamps.removeAll { $0.image_side == "back" }
                        }
                    }
                }
                Button("ライブラリから選択") {
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
                }
                Button("カメラで撑影") {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
                Button("キャンセル", role: .cancel) {}
            }

            if image != nil {
                Button {
                    if target == .front {
                        frontImage = nil; originalFrontImage = nil; newFrontImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "front" }
                    } else {
                        backImage = nil; originalBackImage = nil; newBackImage = nil
                        postsViewModel.pendingStamps.removeAll { $0.image_side == "back" }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                }
                .padding(6)
            }
        }
    }

    // MARK: - Child Section

    // カスタム月齢または自動計算月齢を返す
    private var effectiveAgeMonths: Int {
        if useCustomAge {
            return customAgeYears * 12 + customAgeMonths
        }
        let selectedChild: ChildProfile? = children.indices.contains(selectedChildIndex) ? children[selectedChildIndex] : nil
        let birthday = selectedChild?.birthday ?? authViewModel.currentUser?.child_birthday ?? Date()
        return max(0, Calendar.current.dateComponents([.month], from: birthday, to: Date()).month ?? 0)
    }

    private func ageLabel(_ months: Int) -> String {
        if months < 12 { return "生後\(months)ヶ月" }
        let y = months / 12; let m = months % 12
        return m == 0 ? "\(y)歳" : "\(y)歳\(m)ヶ月"
    }

    // =============================================================================
    // 【Viewサマリー】childSection
    // 目的: 投稿に紐づける子供を選択する水平スクロールセクションを表示する
    // 戻り値: some View
    // =============================================================================
    private var childSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("投稿するお子様")
            if !children.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(children.indices, id: \.self) { idx in
                            let child = children[idx]
                            Button {
                                selectedChildIndex = idx
                                if !useCustomAge {
                                    let bday = child.birthday
                                    let auto = max(0, Calendar.current.dateComponents([.month], from: bday, to: Date()).month ?? 0)
                                    customAgeYears = auto / 12
                                    customAgeMonths = auto % 12
                                }
                            } label: {
                                Text(child.name.isEmpty ? "子供\(idx+1)" : child.name)
                                    .font(.appFont(.medium, size: 13))
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

            // 月齢表示＋カスタマイズUI
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("投稿時の月齢: \(ageLabel(effectiveAgeMonths))")
                        .font(.appFont(.medium, size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle(isOn: $useCustomAge) {
                        Text("変更する")
                            .font(.appFont(.regular, size: 12))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.button)
                    .tint(.accentBlue)
                }
                if useCustomAge {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("年齢（歳）")
                                .font(.caption2).foregroundColor(.secondary)
                            Picker("歳", selection: $customAgeYears) {
                                ForEach(0...10, id: \.self) { y in
                                    Text("\(y)歳").tag(y)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("月数（ヶ月）")
                                .font(.caption2).foregroundColor(.secondary)
                            Picker("ヶ月", selection: $customAgeMonths) {
                                ForEach(0...11, id: \.self) { m in
                                    Text("\(m)ヶ月").tag(m)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    Text("過去の服装を投稿する場合などにご利用ください")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 4)
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
                                .font(.appFont(.regular, size: 18))
                            Text(w.label).font(.appFont(.regular, size: 10))
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
                        .font(.appFont(.regular, size: 22))
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
                    .font(.appFont(.medium, size: 13))
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
                                .font(.appFont(.medium, size: 12))
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
                        .font(.appFont(.bold, size: 10))
                        .foregroundColor(.accentRed)
                    // 番号
                    Text("\(i + 1)")
                        .font(.appFont(.bold, size: 10))
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

    // MARK: - Navigation Title
    private var navigationTitleText: String {
        if isEditMode { return "投稿を編集" }
        if let date = calendarDate {
            let fmt = DateFormatter()
            fmt.dateFormat = "M月d日（E）"
            fmt.locale = Locale(identifier: "ja_JP")
            return fmt.string(from: date)
        }
        return "新しい投稿"
    }

    // =============================================================================
    // 【Viewサマリー】sectionLabel
    // 目的: 各セクションのタイトルラベルを統一スタイルで表示するヘルパー
    // 引数:
    //   - text: String - セクションタイトル
    // 戻り値: some View
    // =============================================================================
    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.appFont(.bold, size: 15)).foregroundColor(.primary)
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
        }
        selectedGender = ChildGender(rawValue: user.child_gender) ?? .unselected
        if isEditMode, let post = editingPost {
            applyEditingPost(post)
        } else if let draft = draftManager.pendingDraft {
            applyDraft(draft)
            draftManager.clearPendingDraft()
        } else {
            fetchWeather()
        }
    }

    private func applyEditingPost(_ post: Post) {
        description = post.description
        weatherType = WeatherType(rawValue: post.weather_type) ?? .sunny
        tempMax = String(format: "%.0f", post.temp_max)
        tempMin = String(format: "%.0f", post.temp_min)
        if let idx = Int(post.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
        useCustomAge = true
        let y = post.child_age_months / 12
        let m = post.child_age_months % 12
        customAgeYears = y
        customAgeMonths = m
        // 既存スタンプをpendingStampsに復元
        if let stamps = post.stamps {
            postsViewModel.pendingStamps = stamps
        }
        // 写真はURLからダウンロードして表示（非同期）
        Task {
            if let urlStr = post.image_url_front, let url = URL(string: urlStr),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                await MainActor.run {
                    frontImage = img
                    originalFrontImage = img
                }
            }
            if let urlStr = post.image_url_back, let url = URL(string: urlStr),
               let (data, _) = try? await URLSession.shared.data(from: url),
               let img = UIImage(data: data) {
                await MainActor.run {
                    backImage = img
                    originalBackImage = img
                }
            }
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
        guard !isSubmitting else { return }  // 既に投稿中なら無視
        guard let user = authViewModel.currentUser else { return }
        
        isSubmitting = true  // 投稿開始

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
            return tag
        }
        let collectedTags: [PostItemTag] = tags
        postsViewModel.setPendingItemTags(collectedTags)

        // ageMonths を選択した子供の誕生日から計算
        var modUser = user
        modUser.child_birthday = effectiveBirthday
        modUser.child_gender = effectiveGender

        // カレンダーからの投稿かどうかを判定
        let isCalendarPost = calendarDate != nil
        
        // 通常投稿：無条件で公開
        // カレンダー投稿：カレンダー公開設定に連動（カレンダー公開時のみ投稿も公開）
        var shouldBePublic = true
        if isCalendarPost {
            let calVm = CalendarViewModel()
            await calVm.fetchCalendarPublicSetting(uid: user.user_id)
            shouldBePublic = calVm.calendarIsPublic
        }

        let success: Bool
        if isEditMode, let post = editingPost {
            success = await postsViewModel.updatePost(
                existingPost: post,
                newFrontImage: newFrontImage,
                newBackImage: newBackImage,
                description: description,
                regionCode: regionCode,
                genderId: effectiveGender,
                weatherType: weatherType.rawValue,
                tempMax: tMax,
                tempMin: tMin,
                items: postItems,
                overrideAgeMonths: useCustomAge ? effectiveAgeMonths : nil
            )
        } else {
            success = await postsViewModel.uploadPost(
                frontImage: frontImage,
                backImage: backImage,
                description: description,
                regionCode: regionCode,
                genderId: effectiveGender,
                weatherType: weatherType.rawValue,
                tempMax: tMax,
                tempMin: tMin,
                items: postItems,
                user: modUser,
                isPublic: shouldBePublic,
                isCalendarPost: isCalendarPost,
                overrideAgeMonths: useCustomAge ? effectiveAgeMonths : nil
            )
        }

        if success {
            UserDefaults.standard.removeObject(forKey: "postDraft")
            if let draftId = editingDraftId {
                draftManager.deleteDraftById(draftId)
            }

            // カレンダーからの投稿（calendarDate != nil）の場合のみ、カレンダー日記を作成
            if let targetDate = calendarDate {
                let uid = user.user_id
                let dateKey = CalendarView.dateKey(for: targetDate)
                let calVm = CalendarViewModel()
                await calVm.fetchCalendarPublicSetting(uid: uid)
                let saved = await calVm.saveEntry(
                    uid: uid,
                    dateKey: dateKey,
                    comment: description,
                    image: frontImage,
                    regionCode: regionCode
                )
                // 天気情報も保存
                let weather = WeatherResult(tempMax: tMax, tempMin: tMin, weatherType: weatherType.rawValue)
                await calVm.updateWeather(uid: uid, dateKey: dateKey, weather: weather)
                // カレンダー画面に通知
                NotificationCenter.default.post(name: Notification.Name("CalendarEntryUpdated"), object: nil)
            } else {
            }
            showSuccess = true
        } else { showError = true }
        
        isSubmitting = false  // 投稿完了
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

struct NewItemEntry: Identifiable, Equatable {
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
                    .font(.appFont(.medium, size: 11))
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
                            .font(.appFont(.medium, size: 11))
                        Text("タグ付け")
                            .font(.appFont(.medium, size: 12))
                        if entry.tagPosition != nil {
                            Text(entry.tagSide == "front" ? "F" : "B")
                                .font(.appFont(.bold, size: 10))
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
                            .font(.appFont(.medium, size: 12))
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
                .fixedSize()
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
    @ObservedObject private var brandService = BrandService.shared

    private var filteredBrands: [BrandEntry] {
        filterBrands(brandService.brands, query: query)
    }

    // 入力されたブランド名をブランド一覧内の正式名称に正規化して返す
    private func canonicalBrandName(for input: String) -> String {
        let normalizedInput = normalizeForSearch(input)
        // マッチする正式名称があればそれを返す
        if let match = brandService.brands.first(where: { normalizeForSearch($0.name) == normalizedInput }) {
            return match.name
        }
        // 読み仮名完全一致も探す
        if let readingMatch = brandService.brands.first(where: { $0.reading == normalizedInput }) {
            return readingMatch.name
        }
        // 部分一致も探す（「ユニクロ」→「UNIQLO」など）
        if let partial = brandService.brands.first(where: {
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
                                .font(.appFont(.regular, size: 14))
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
                            .font(.appFont(.regular, size: 14))
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
                                            .font(.appFont(.regular, size: 15))
                                            .foregroundColor(.primary)
                                        Text(brand.reading)
                                            .font(.appFont(.regular, size: 12))
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
        .navigationViewStyle(StackNavigationViewStyle())
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
    var color: Color = .white
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
    var defaultColor: Color { .white }
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
    let imageSide: String  // "front" または "back"
    let onDone: (UIImage) -> Void
    let onSaveStamps: ([PostStamp]) -> Void  // スタンプ保存時のコールバック
    var existingStamps: [PostStamp] = []  // 既存スタンプ（編集時）
    @Environment(\.dismiss) private var dismiss

    @State private var stampItems: [PlacedStamp] = []
    @State private var selectedKind: StampKind? = nil
    @State private var history: [EditorAction] = []
    @State private var canvasSize: CGSize = .zero
    @State private var canvasOffset: CGPoint = .zero
    @State private var activeStampId: UUID? = nil

    private let pickerColors: [Color] = [
        .black, .white, .red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                stampPalette
                ZStack(alignment: .bottom) {
                    canvas
                    if let activeId = activeStampId {
                        VStack(spacing: 8) {
                            colorPickerRow(activeId: activeId)
                            trashButton(activeId: activeId)
                        }
                        .padding(.bottom, 12)
                    }
                }
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
                        // スタンプ情報を変換して保存（現在の正確なcanvasSizeを使用）
                        let postStamps = convertToPostStamps(stampItems: stampItems, canvasSize: canvasSize, imageSide: imageSide)
                        onSaveStamps(postStamps)
                        // 現在のcanvasSizeをその場で渡してレンダリング（状態変化前に確定）
                        let finalImage = renderFinalImage(currentCanvasSize: canvasSize)
                        onDone(finalImage)
                        dismiss()
                    } label: {
                        Text("完了").font(.appFont(.bold, size: 15))
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Color Picker Row
    private func colorPickerRow(activeId: UUID) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pickerColors.indices, id: \.self) { i in
                    let col = pickerColors[i]
                    let isSelected: Bool = {
                        if let idx = stampItems.firstIndex(where: { $0.id == activeId }) {
                            return stampItems[idx].color == col
                        }
                        return false
                    }()
                    Button {
                        if let idx = stampItems.firstIndex(where: { $0.id == activeId }) {
                            if isSelected {
                                stampItems[idx].color = .white
                            } else {
                                stampItems[idx].color = col
                            }
                        }
                    } label: {
                        Circle()
                            .fill(col)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.9), lineWidth: isSelected ? 3 : 1)
                            )
                            .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45))
        .cornerRadius(16)
        .padding(.horizontal, 32)
    }

    // MARK: - Trash Button
    private func trashButton(activeId: UUID) -> some View {
        Button {
            if let idx = stampItems.firstIndex(where: { $0.id == activeId }) {
                history.append(.removeStamp(stampItems[idx]))
                stampItems.remove(at: idx)
            }
            activeStampId = nil
        } label: {
            Image(systemName: "trash.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(14)
                .background(Color.red.opacity(0.85))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .buttonStyle(.plain)
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
                            .font(.appFont(.regular, size: 24))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(selectedKind == kind ? Color(UIColor.systemGray) : Color(UIColor.systemGray2))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedKind == kind ? Color.white.opacity(0.8) : Color.clear, lineWidth: 2)
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
    //        画像とスタンプを同じサイズのコンテナに入れ、offsetX/Yを使わない設計
    // 戻り値: some View
    // =============================================================================
    private var canvas: some View {
        GeometryReader { geo in
            // 1. 画面全体のサイズに画像がどう収まるか（実際の表示サイズ）を計算
            let displaySize = calculateFitSize(canvasSize: geo.size, imageSize: image.size)

            // 2. 画面の中央に、画像と「全く同じサイズ」のスタンプ配置エリアを作る
            // alignment: .topLeading で左上を原点とする座標系に統一
            ZStack(alignment: .topLeading) {
                // 背景画像（余白なしのジャストサイズで配置）
                Image(uiImage: image)
                    .resizable()
                    .frame(width: displaySize.width, height: displaySize.height)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { val in
                                guard let kind = selectedKind else { return }
                                // ZStack(alignment: .topLeading) なので座標をそのまま使う
                                let position = CGPoint(
                                    x: max(0, min(val.location.x, displaySize.width)),
                                    y: max(0, min(val.location.y, displaySize.height))
                                )
                                let stamp = PlacedStamp(kind: kind, position: position, color: .white)
                                stampItems.append(stamp)
                                history.append(.addStamp(stamp))
                                activeStampId = stamp.id
                                selectedKind = nil
                            }
                    )

                // スタンプ編集レイヤー（画像と完全に同じ枠になる）
                ForEach($stampItems) { $stamp in
                    StampView(stamp: $stamp,
                              canvasOffset: .zero,
                              isActive: activeStampId == stamp.id,
                              onTap: { activeStampId = stamp.id })
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .onAppear {
                // canvasSizeをこの「画像表示サイズ」で上書き（offsetなし）
                canvasSize = displaySize
                canvasOffset = .zero
                loadExistingStamps()
            }
        }
    }

    // ヘルパー関数: Aspect Fit された実際の表示サイズを計算する
    private func calculateFitSize(canvasSize: CGSize, imageSize: CGSize) -> CGSize {
        let scale = min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    // MARK: - Hint
    // 説明: スタンプ編集画面の操作ヒントテキスト

    // =============================================================================
    // 【Viewサマリー】hintText
    // 目的: スタンプ編集画面の操作ガイドを表示する
    // 戻り値: some View
    // =============================================================================
    private var hintText: some View {
        Text(selectedKind != nil ? "タップで配置" : (activeStampId != nil ? "ゴミ箱で削除 • カラーで色変更 • ドラッグで移動" : "スタンプを選択 • タップで選択 • ドラッグで移動"))
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
    //        offsetなし：canvasSizeが画像ぴったりサイズなので単純計算
    //        currentCanvasSize: 完了ボタン押下時点の正確なサイズを引数で受け取る
    // =============================================================================
    private func renderFinalImage(currentCanvasSize: CGSize) -> UIImage {
        let imgW = image.size.width
        let imgH = image.size.height

        // canvasSizeが画像ぴったりサイズなので、単純に拡大率を計算
        let fitScale = currentCanvasSize.width / imgW


        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: imgW, height: imgH), format: format)

        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: imgW, height: imgH)))

            for stamp in stampItems {
                // canvasSizeが画像ぴったりサイズなので、単に拡大率で割るだけで完璧に一致
                let imgX = stamp.position.x / fitScale
                let imgY = stamp.position.y / fitScale


                // スタンプサイズも元画像サイズに合わせて拡大
                let uiSize: CGFloat = 44 * stamp.scale
                let stampImgPt = uiSize / fitScale

                let drawImage: UIImage?
                switch stamp.kind {
                case .symbol(let sym):
                    let config = UIImage.SymbolConfiguration(pointSize: stampImgPt, weight: .bold)
                    let baseImg = UIImage(systemName: sym.rawValue, withConfiguration: config)
                    drawImage = baseImg?.withTintColor(UIColor(stamp.color), renderingMode: .alwaysOriginal)
                case .image(let name):
                    drawImage = UIImage(named: name)
                }

                if let img = drawImage {
                    ctx.cgContext.saveGState()
                    ctx.cgContext.translateBy(x: imgX, y: imgY)
                    ctx.cgContext.rotate(by: CGFloat(stamp.rotation.radians))
                    let rect = CGRect(x: -stampImgPt / 2, y: -stampImgPt / 2, width: stampImgPt, height: stampImgPt)
                    img.draw(in: rect)
                    ctx.cgContext.restoreGState()
                }
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】getFitScale
    // 目的: 画像をcanvasにfitさせるためのスケールを計算
    // =============================================================================
    private func getFitScale(canvasSize: CGSize, imageSize: CGSize) -> CGFloat {
        return min(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height)
    }

    // =============================================================================
    // 【関数サマリー】loadExistingStamps
    // 目的: 既存スタンプをPhotoEditorViewに復元（offsetなし・シンプル設計）
    //        canvasSizeが画像ぴったりサイズなので、単純な比率計算で復元
    // =============================================================================
    private func loadExistingStamps() {
        guard image.size.width > 0, canvasSize.width > 0 else { return }

        stampItems.removeAll() // 重複防止のために必ずクリア
        let restored = existingStamps.compactMap { postStamp -> PlacedStamp? in
            guard let stampKind = postStamp.stampKind else { return nil }

            // 余白を足す処理が不要：canvasSizeが画像ぴったりサイズ
            let position = CGPoint(
                x: CGFloat(postStamp.x_ratio) * canvasSize.width,
                y: CGFloat(postStamp.y_ratio) * canvasSize.height
            )
            let restoredColor: Color = postStamp.color_hex.flatMap { Color(hex: $0) } ?? .white
            return PlacedStamp(
                kind: stampKind,
                position: position,
                scale: CGFloat(postStamp.scale),
                rotation: Angle(radians: postStamp.rotation),
                color: restoredColor
            )
        }
        stampItems = restored
    }

    // =============================================================================
    // 【関数サマリー】convertToPostStamps
    // 目的: PlacedStamp配列をPostStamp配列に変換（Firestore保存用）
    //        offsetなし：canvasSizeが画像ぴったりサイズなので単純比率計算
    // =============================================================================
    private func convertToPostStamps(stampItems: [PlacedStamp], canvasSize: CGSize, imageSide: String) -> [PostStamp] {
        return stampItems.map { stamp in
            let kindType: String
            let kindValue: String
            switch stamp.kind {
            case .symbol(let sym):
                kindType = "symbol"
                kindValue = sym.rawValue
            case .image(let name):
                kindType = "image"
                kindValue = name
            }
            // 余白を引く処理が不要：canvasSizeが画像ぴったりサイズ
            let xRatio = stamp.position.x / canvasSize.width
            let yRatio = stamp.position.y / canvasSize.height
            return PostStamp(
                id: stamp.id.uuidString,
                kind_type: kindType,
                kind_value: kindValue,
                x_ratio: Double(max(0, min(1, xRatio))),
                y_ratio: Double(max(0, min(1, yRatio))),
                scale: Double(stamp.scale),
                rotation: Double(stamp.rotation.radians),
                image_side: imageSide,
                color_hex: stamp.color.toHex()
            )
        }
    }
}

// MARK: - StampView (個別スタンプ操作)

struct StampView: View {
    @Binding var stamp: PlacedStamp
    let canvasOffset: CGPoint
    let isActive: Bool
    let onTap: () -> Void

    private let baseSize: CGFloat = 44

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var rotationAngle: Angle = .zero
    @State private var liveScaleFactor: CGFloat = 1.0

    var body: some View {
        Group {
            switch stamp.kind {
            case .symbol(let sym):
                Image(systemName: sym.rawValue)
                    .font(.appFont(.regular, size: baseSize))
                    .foregroundColor(stamp.color)
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
                        // 拡縮ハンドル（右上）
                        Image(systemName: "arrow.up.and.down")
                            .font(.appFont(.bold, size: 11))
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
        // .offset()を使用：左上を原点とする絶対座標（ZStack(alignment: .topLeading)と一致）
        .offset(
            x: stamp.position.x + canvasOffset.x + dragOffset.width - baseSize / 2,
            y: stamp.position.y + canvasOffset.y + dragOffset.height - baseSize / 2
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
            TapGesture().onEnded { onTap() }
        )
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
                                    .font(.appFont(.medium, size: 14))
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
                    .font(.appFont(.bold, size: 10))
                    .foregroundColor(i == itemIndex ? .white : .accentRed)
                Text("\(i + 1)")
                    .font(.appFont(.bold, size: 10))
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

