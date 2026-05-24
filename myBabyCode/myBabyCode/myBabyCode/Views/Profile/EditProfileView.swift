import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedAvatarId: String = "🐶"
    @State private var selectedRegionIndex: Int = 12
    @State private var childBirthday: Date = Date()
    @State private var selectedGender: ChildGender = .unselected
    @State private var children: [ChildProfile] = []
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            if avatarImageNames.isEmpty {
                                // 画像未追加時は絵文字で表示
                                ForEach(avatarEmojis, id: \.self) { emoji in
                                    Button {
                                        selectedAvatarId = emoji
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(width: 52, height: 52)
                                            .background(selectedAvatarId == emoji ? Color.indigo.opacity(0.15) : Color(.systemGray6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(selectedAvatarId == emoji ? Color.indigo : Color.clear, lineWidth: 2)
                                            )
                                            .cornerRadius(14)
                                    }
                                }
                            } else {
                                // AvatarIcons/ に画像が追加されたら自動で画像グリッドに切り替わる
                                ForEach(avatarImageNames, id: \.self) { name in
                                    Button {
                                        selectedAvatarId = name
                                    } label: {
                                        Image(name)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 52, height: 52)
                                            .background(selectedAvatarId == name ? Color.indigo.opacity(0.15) : Color(.systemGray6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(selectedAvatarId == name ? Color.indigo : Color.clear, lineWidth: 2)
                                            )
                                            .cornerRadius(14)
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
                                    .foregroundColor(.indigo)
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
                            .background(Color.indigo)
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
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
    }

    private func loadExistingData() {
        guard let user = authViewModel.currentUser else { return }
        displayName = user.display_name ?? ""
        selectedAvatarId = user.avatar_id
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
        user.display_name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
        user.avatar_id = selectedAvatarId
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
        .background(Color(.systemIndigo).opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.15), lineWidth: 1))
    }
}
