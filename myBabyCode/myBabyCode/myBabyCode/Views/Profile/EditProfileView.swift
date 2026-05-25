// =============================================================================
// ファイル名: EditProfileView.swift
// 役割: プロフィール編集画面（表示名・ユーザーID・アバター・背景色・子供情報の変更）
// 説明:
//   マイページの設定から遷移するプロフィール編集画面です。
//   表示名、ユーザーID、アバター画像・背景色、居住地域、子供の名前・生年月日・性別を
//   変更できます。変更内容はAuthViewModel.updateProfile()を通じてFirestoreに保存されます。
// =============================================================================

import SwiftUI

struct EditProfileView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // === 編集項目 ===
    @State private var displayName: String = ""           // 表示名
    @State private var uniqueUserId: String = ""        // 一意のユーザーID
    @State private var selectedAvatarId: String = "bear"  // アバター識別子
    @State private var selectedBgColorHex: String = "#FFEEBA"  // アバター背景色
    @State private var showAvatarImagePicker = false      // 画像ピッカー表示フラグ
    @State private var pickedAvatarImage: UIImage? = nil  // 選択したアバター画像
    @State private var isUploadingAvatar = false          // アバターアップロード中フラグ
    @State private var selectedRegionIndex: Int = 12    // 都道府県インデックス
    @State private var childBirthday: Date = Date()       // 子供の生年月日
    @State private var selectedGender: ChildGender = .unselected  // 子供の性別
    @State private var children: [ChildProfile] = []    // 子供プロフィールリスト
    @State private var isSaving = false                   // 保存処理中フラグ

    // アバター背景色のプリセット選択肢
    private let bgColorOptions: [(label: String, hex: String)] = [
        ("ふんわり", "#FFEEBA"),
        ("空", "#D0EAFA"),
        ("草", "#D4EDD8"),
        ("桃", "#FFD6D6"),
        ("ラベンダー", "#E8D8F0"),
        ("白", "#FFFFFF"),
        ("グレー", "#E0E0E0"),
    ]

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: プロフィール編集画面の全体レイアウトを定義
    // 構成:
    //   1. ユーザーID入力
    //   2. 表示名入力
    //   3. アバター選択（ライブラリ・背景色プリセット）
    //   4. 地域選択
    //   5. 子供情報（名前・生年月日・性別）
    //   6. 保存ボタン
    // =============================================================================
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Unique User ID
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("ユーザーID")
                        TextField("例: nanikiru_mama", text: $uniqueUserId)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Text("他のユーザーから識別できるIDです。表示名とは別です。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Display name
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("表示名")
                        TextField("例: たまごママ", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        Text("アプリ内で表示される名前です。本名は使用しないでください。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Avatar selection
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("アバターアイコン")

                        Text("個人が特定できる写真の使用はお控えください")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        // ライブラリから選択ボタン
                        Button {
                            showAvatarImagePicker = true
                        } label: {
                            Label("ライブラリから写真を選ぶ", systemImage: "photo")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.accentBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.accentBlue.opacity(0.08))
                                .cornerRadius(10)
                        }
                        if let img = pickedAvatarImage {
                            HStack(spacing: 10) {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                                Text("選択中の写真").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                if isUploadingAvatar { ProgressView().scaleEffect(0.8) }
                                Button {
                                    pickedAvatarImage = nil
                                    selectedAvatarId = "bear"
                                } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                                }
                            }
                        }

                        // アセット画像グリッド
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(avatarImageNames, id: \.self) { name in
                                Button {
                                    selectedAvatarId = name
                                    pickedAvatarImage = nil
                                } label: {
                                    Image(name)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
                                        .background(selectedAvatarId == name && pickedAvatarImage == nil ? Color.accentBlue.opacity(0.12) : Color(.systemGray6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedAvatarId == name && pickedAvatarImage == nil ? Color.accentBlue : Color.clear, lineWidth: 2)
                                        )
                                        .cornerRadius(14)
                                }
                            }
                        }

                        // 背景色選択
                        VStack(alignment: .leading, spacing: 6) {
                            Text("アイコン背景色")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 10) {
                                ForEach(bgColorOptions, id: \.hex) { opt in
                                    Button {
                                        selectedBgColorHex = opt.hex
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: opt.hex))
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedBgColorHex == opt.hex ? Color.primary : Color.clear, lineWidth: 2)
                                            )
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    // Children management
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionLabel("お子様の情報（複数登録可）")
                            Spacer()
                            Button {
                                children.append(ChildProfile(name: "", birthday: Date(), gender: 0))
                            } label: {
                                Label("追加", systemImage: "plus.circle.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.accentGreen)
                            }
                        }

                        Text("お子様のニックネームを登録してください。本名は入力しないことをおすすめします。")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if children.isEmpty {
                            Text("「追加」ボタンでお子様を登録できます")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }

                        ForEach(children.indices, id: \.self) { idx in
                            ChildProfileRow(
                                child: $children[idx],
                                onRemove: { children.remove(at: idx) }
                            )
                        }
                    }

                    Divider()

                    // Region
                    VStack(alignment: .leading, spacing: 6) {
                        sectionLabel("お住まいの地域")
                        Picker("地域", selection: $selectedRegionIndex) {
                            ForEach(prefectures.indices, id: \.self) { i in
                                Text(prefectures[i]).tag(i)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }

                    // Save
                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "保存中..." : "保存する")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentRed)
                            .cornerRadius(16)
                    }
                    .disabled(isSaving)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .navigationTitle("プロフィール設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { loadExistingData() }
            .sheet(isPresented: $showAvatarImagePicker) {
                ImagePickerView(sourceType: .photoLibrary) { img in
                    pickedAvatarImage = img
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
    }

    private func loadExistingData() {
        guard let user = authViewModel.currentUser else { return }
        displayName = user.display_name ?? ""
        uniqueUserId = user.unique_user_id ?? ""
        selectedAvatarId = user.avatar_id
        selectedBgColorHex = user.avatar_bg_color ?? "#FFEEBA"
        childBirthday = user.child_birthday
        selectedGender = ChildGender(rawValue: user.child_gender) ?? .unselected
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
        children = user.children ?? []
    }

    private func save() async {
        guard var user = authViewModel.currentUser else { return }
        isSaving = true
        let trimmedUniqueId = uniqueUserId.trimmingCharacters(in: .whitespaces)
        user.unique_user_id = trimmedUniqueId.isEmpty ? nil : trimmedUniqueId
        user.display_name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
        if let img = pickedAvatarImage {
            do {
                isUploadingAvatar = true
                let url = try await authViewModel.uploadAvatarImage(img)
                user.avatar_id = url
                isUploadingAvatar = false
            } catch {
                isUploadingAvatar = false
            }
        } else {
            user.avatar_id = selectedAvatarId
        }
        user.avatar_bg_color = selectedBgColorHex
        user.child_birthday = childBirthday
        user.child_gender = selectedGender.rawValue
        user.region_code = String(format: "%02d", selectedRegionIndex + 1)
        user.children = children.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
        await authViewModel.saveUserProfile(user)
        isSaving = false
        dismiss()
    }
}

// MARK: - ChildProfileRow

struct ChildProfileRow: View {
    @Binding var child: ChildProfile
    var onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("お子様").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.7))
                }
            }

            TextField("ニックネーム（例: はるくん）※本名不要", text: $child.name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("生年月日").font(.caption).foregroundColor(.secondary)
                    DatePicker("", selection: $child.birthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("性別").font(.caption).foregroundColor(.secondary)
                    Picker("性別", selection: $child.gender) {
                        ForEach(ChildGender.allCases) { g in
                            Text(g.label).tag(g.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color.ecruBackground.opacity(0.9))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1))
    }
}
