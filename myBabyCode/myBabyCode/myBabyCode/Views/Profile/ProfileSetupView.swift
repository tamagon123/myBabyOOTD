// =============================================================================
// ファイル名: ProfileSetupView.swift
// 役割: 初回プロフィール設定画面（アバター・表示名・ユーザーID・地域・子供情報）
// 説明:
//   新規登録後に表示される初回プロフィール設定画面です。
//   必須項目としてユーザーID（unique_user_id）、表示名（display_name）、
//   地域（region_code）を入力し、任意でアバター画像・背景色・子供の
//   プロフィール（名前・生年月日・性別）を設定できます。
//   入力完了後、AuthViewModel.completeProfile()を呼び出してFirestoreに保存します。
// =============================================================================

import SwiftUI

struct ProfileSetupView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // === 必須入力項目 ===
    @State private var uniqueUserId: String = ""   // 一意のユーザーID（英数字・記号）
    @State private var displayName: String = ""    // 画面に表示される名前
    @State private var regionIndex: Int = 12       // 都道府県インデックス（デフォルト: 東京都）

    // === アバター設定 ===
    @State private var avatarId: String = "bear"          // アバター識別子（画像名/URL/絵文字）
    @State private var avatarBgColor: String = "#FFEEBA"  // アバター背景色（HEX）
    @State private var selectedAvatarImage: UIImage? = nil  // ライブラリから選択した画像
    @State private var showImagePicker: Bool = false      // 画像ピッカー表示フラグ
    @State private var showAvatarPicker: Bool = false     // アバター選択シート表示フラグ

    // === 子供情報（任意） ===
    @State private var showChildInput: Bool = false  // 子供入力セクションの展開フラグ
    @State private var childName: String = ""       // 子供のニックネーム
    @State private var childBirthday: Date = Date() // 子供の生年月日
    @State private var childGender: Int = 0         // 子供の性別（0=未選択,1=男,2=女,3=その他）

    // === バリデーション ===
    @State private var isCheckingId: Bool = false   // ユーザーID重複チェック中フラグ
    @State private var idAvailable: Bool? = nil     // ユーザーIDの重複チェック結果
    @State private var showError: Bool = false      // エラー表示フラグ

    // 計算プロパティ: 送信可能かどうか（必須項目入力＆ID未重複）
    private var canSubmit: Bool {
        !uniqueUserId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        idAvailable != false
    }

    // プリセットのアバター背景色（パステル系）
    private let presetColors: [String] = [
        "#FFEEBA", // Light yellow (default)
        "#FFD1DC", // Pastel pink
        "#C1E1C1", // Pastel green
        "#B4D7F0", // Pastel blue
        "#E6E6FA", // Lavender
        "#FFDAB9", // Peach
        "#F0E68C", // Khaki
    ]

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: プロフィール設定画面の全体レイアウトを定義
    // 構成:
    //   1. ヘッダー: 「プロフィール設定」タイトル＋説明文
    //   2. アバターセクション: 画像選択・背景色選択
    //   3. 入力フィールド: 表示名・ユーザーID（重複チェック付き）・地域
    //   4. 子供情報セクション（任意）: 名前・生年月日・性別
    //   5. 保存ボタン
    // =============================================================================
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text("プロフィール設定")
                            .font(.system(size: 24, weight: .bold))
                        Text("アカウント作成を完了するために、以下の情報を入力してください")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Avatar Section
                    avatarSection

                    // Input Fields
                    VStack(spacing: 16) {
                        // Display Name
                        VStack(alignment: .leading, spacing: 4) {
                            Text("表示名 *")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            TextField("例: ゆうまま", text: $displayName)
                                .textContentType(.name)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(14)
                                .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                        }

                        // Unique User ID
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ユーザーID *（変更不可）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            HStack {
                                TextField("例: nanikiru_mama (半角英数字・_)", text: $uniqueUserId)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .onChange(of: uniqueUserId) { val in
                                        idAvailable = nil
                                        guard !val.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                        isCheckingId = true
                                        Task {
                                            try? await Task.sleep(nanoseconds: 600_000_000)
                                            idAvailable = await authViewModel.checkUniqueUserIdAvailable(val.trimmingCharacters(in: .whitespaces))
                                            isCheckingId = false
                                        }
                                    }
                                if isCheckingId {
                                    ProgressView().scaleEffect(0.8)
                                } else if let ok = idAvailable {
                                    Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(ok ? .accentGreen : .red)
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                            if idAvailable == false {
                                Text("そのユーザーIDは既に使われています")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                            }
                        }

                        // Region
                        VStack(alignment: .leading, spacing: 4) {
                            Text("お住まいの地域 *")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                            Picker("地域", selection: $regionIndex) {
                                ForEach(prefectures.indices, id: \.self) { i in
                                    Text(prefectures[i]).tag(i)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                        }
                    }

                    // Child Info Section
                    childInfoSection

                    // Privacy notice
                    Text("※ アバター画像は他のユーザーに公開されます。個人が特定される写真は避けてください。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Submit Button
                    Button(action: completeProfile) {
                        Group {
                            if authViewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("プロフィールを保存")
                                    .font(.system(size: 17, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSubmit ? Color.accentRed : Color.gray)
                        .cornerRadius(16)
                    }
                    .disabled(!canSubmit || authViewModel.isLoading)

                    if let error = authViewModel.errorMessage, showError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 28)
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: .photoLibrary) { image in
                    selectedAvatarImage = image
                    // Upload and get URL
                    Task {
                        do {
                            let url = try await authViewModel.uploadAvatarImage(image)
                            avatarId = url
                        } catch {
                            print("[ProfileSetup] Avatar upload failed: \(error)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAvatarPicker) {
                AvatarPickerView(selectedAvatarId: $avatarId, isPresented: $showAvatarPicker)
            }
        }
    }

    // MARK: - Avatar Section
    private var avatarSection: some View {
        VStack(spacing: 16) {
            // Avatar display
            ZStack {
                if let selectedImage = selectedAvatarImage {
                    // Selected library image (preview before upload)
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                } else if avatarId.hasPrefix("https://") {
                    AsyncImage(url: URL(string: avatarId)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.ecruBackground
                    }
                } else if avatarImageNames.contains(avatarId) {
                    Image(avatarId).resizable().scaledToFill()
                } else if avatarId.count == 1 || avatarId.count == 2 {
                    // Emoji avatar (1 or 2 character emoji string)
                    Text(avatarId)
                        .font(.system(size: 56))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)
            .background(Color(hex: avatarBgColor))
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 3))
            .shadow(radius: 4)

            // Avatar selection buttons
            HStack(spacing: 16) {
                Button {
                    selectedAvatarImage = nil
                    showAvatarPicker = true
                } label: {
                    Label("アバターを選択", systemImage: "face.smiling")
                        .font(.system(size: 13))
                        .foregroundColor(.accentRed)
                }

                Button {
                    showImagePicker = true
                } label: {
                    Label("ライブラリから選択", systemImage: "photo")
                        .font(.system(size: 13))
                        .foregroundColor(.accentRed)
                }
            }

            // Background color selection
            VStack(alignment: .leading, spacing: 8) {
                Text("アバター背景色")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    ForEach(presetColors, id: \.self) { color in
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(avatarBgColor == color ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                avatarBgColor = color
                            }
                    }
                }
            }
        }
    }

    // MARK: - Child Info Section
    private var childInfoSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("子供の情報（任意）")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Toggle("", isOn: $showChildInput)
                    .tint(.accentRed)
            }

            if showChildInput {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ニックネーム")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        TextField("例: ゆうちゃん", text: $childName)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("誕生日")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        DatePicker("", selection: $childBirthday, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("性別")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        Picker("", selection: $childGender) {
                            Text("未選択").tag(0)
                            Text("男の子").tag(1)
                            Text("女の子").tag(2)
                            Text("その他").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Actions
    private func completeProfile() {
        showError = false
        let code = String(format: "%02d", regionIndex + 1)

        // Build children array if input is enabled
        var children: [ChildProfile]? = nil
        if showChildInput && !childName.isEmpty {
            children = [ChildProfile(
                id: UUID().uuidString,
                name: childName,
                birthday: childBirthday,
                gender: childGender
            )]
        }

        Task {
            let success = await authViewModel.completeProfile(
                uniqueUserId: uniqueUserId.trimmingCharacters(in: .whitespaces),
                displayName: displayName.trimmingCharacters(in: .whitespaces),
                regionCode: code,
                avatarId: avatarId,
                avatarBgColor: avatarBgColor,
                children: children
            )
            if !success {
                showError = true
            }
        }
    }
}

// MARK: - Avatar Picker View
struct AvatarPickerView: View {
    @Binding var selectedAvatarId: String
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Image Avatars Section
                    if !avatarImageNames.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("キャラクター")
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                                ForEach(avatarImageNames, id: \.self) { name in
                                    avatarButton(name: name, isImage: true)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Emoji Avatars Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("アイコン")
                            .font(.system(size: 16, weight: .semibold))
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                            ForEach(avatarEmojis, id: \.self) { emoji in
                                emojiButton(emoji: emoji)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.vertical)
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("アバターを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { isPresented = false }
                }
            }
        }
    }

    private func avatarButton(name: String, isImage: Bool) -> some View {
        Button {
            selectedAvatarId = name
            isPresented = false
        } label: {
            ZStack {
                if isImage {
                    Image(name)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedAvatarId == name ? Color.accentRed : Color.clear, lineWidth: 3)
            )
        }
    }

    private func emojiButton(emoji: String) -> some View {
        Button {
            selectedAvatarId = emoji
            isPresented = false
        } label: {
            Text(emoji)
                .font(.system(size: 40))
                .frame(width: 60, height: 60)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedAvatarId == emoji ? Color.accentRed : Color.clear, lineWidth: 3)
                )
        }
    }
}

// MARK: - Preview
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
            .environmentObject(AuthViewModel())
    }
}
