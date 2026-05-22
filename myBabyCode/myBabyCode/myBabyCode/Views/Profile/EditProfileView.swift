import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedAvatarId: String = "🐶"
    @State private var selectedRegionIndex: Int = 12
    @State private var isSaving = false
    @State private var showAddChild = false
    @State private var editingChild: Child? = nil
    @State private var showError = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Display name
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("表示名")
                        TextField("例: たまきママ", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                        Text("投稿者名として表示されます（20文字以内）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Avatar
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("アバターアイコン")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                            ForEach(avatarEmojis, id: \.self) { emoji in
                                Button {
                                    selectedAvatarId = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 28))
                                        .frame(width: 52, height: 52)
                                        .background(selectedAvatarId == emoji ? Color.indigo.opacity(0.15) : Color(.systemGray6))
                                        .overlay(RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedAvatarId == emoji ? Color.indigo : Color.clear, lineWidth: 2))
                                        .cornerRadius(14)
                                }
                            }
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

                    Divider()

                    // Children
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            sectionLabel("お子様の情報")
                            Spacer()
                            Button {
                                showAddChild = true
                            } label: {
                                Label("追加", systemImage: "plus.circle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.indigo)
                            }
                        }

                        if authViewModel.children.isEmpty {
                            Text("お子様を追加してください")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        } else {
                            ForEach(authViewModel.children) { child in
                                childRow(child)
                            }
                        }
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
            .alert("エラー", isPresented: $showError) {
                Button("OK") { authViewModel.errorMessage = nil }
            } message: {
                Text(errorText)
            }
            .onChange(of: authViewModel.errorMessage) { _, msg in
                if let msg = msg, !msg.isEmpty {
                    errorText = msg
                    showError = true
                }
            }
            .sheet(isPresented: $showAddChild) {
                ChildEditSheet(child: nil)
                    .environmentObject(authViewModel)
            }
            .sheet(item: $editingChild) { child in
                ChildEditSheet(child: child)
                    .environmentObject(authViewModel)
            }
        }
    }

    // MARK: - Child row

    @ViewBuilder
    private func childRow(_ child: Child) -> some View {
        HStack(spacing: 12) {
            Text(ChildGender(rawValue: child.gender)?.emoji ?? "🧒")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color(.systemYellow).opacity(0.3))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(child.name.isEmpty ? "名前未設定" : child.name)
                    .font(.system(size: 15, weight: .bold))
                let months = Calendar.current.dateComponents([.month], from: child.birthday, to: Date()).month ?? 0
                let ageStr = months < 12 ? "生後\(months)ヶ月" : "\(months/12)歳\(months%12 == 0 ? "" : "\(months%12)ヶ月")"
                Text("\(ageStr) • \(ChildGender(rawValue: child.gender)?.label ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                editingChild = child
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title3)
                    .foregroundColor(.indigo)
            }
            Button {
                Task { await authViewModel.deleteChild(child) }
            } label: {
                Image(systemName: "trash.circle")
                    .font(.title3)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 15, weight: .bold))
    }

    private func loadExistingData() {
        guard let user = authViewModel.currentUser else { return }
        displayName = user.display_name
        selectedAvatarId = user.avatar_id
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
    }

    private func save() async {
        guard var user = authViewModel.currentUser else {
            errorText = "ユーザー情報が取得できません。再ログインしてください。"
            showError = true
            return
        }
        isSaving = true
        authViewModel.errorMessage = nil
        user.display_name = String(displayName.prefix(20))
        user.avatar_id = selectedAvatarId
        user.region_code = String(format: "%02d", selectedRegionIndex + 1)
        await authViewModel.saveUserProfile(user)
        isSaving = false
        if authViewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - ChildEditSheet

struct ChildEditSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    let child: Child?   // nil = 新規追加

    @State private var name: String = ""
    @State private var birthday: Date = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var gender: ChildGender = .unselected
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorText = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("名前（ニックネーム）").font(.subheadline).foregroundColor(.secondary)
                    TextField("例: はな", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                // Birthday
                VStack(alignment: .leading, spacing: 6) {
                    Text("生年月日").font(.subheadline).foregroundColor(.secondary)
                    DatePicker("", selection: $birthday, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ja_JP"))
                }

                // Gender
                VStack(alignment: .leading, spacing: 6) {
                    Text("性別").font(.subheadline).foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        ForEach(ChildGender.allCases) { g in
                            Button {
                                gender = g
                            } label: {
                                Text(g.label)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(gender == g ? Color.indigo : Color(.systemGray6))
                                    .foregroundColor(gender == g ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    Task { await saveChild() }
                } label: {
                    Text(isSaving ? "保存中..." : (child == nil ? "追加する" : "更新する"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.indigo)
                        .cornerRadius(16)
                }
                .disabled(isSaving)
            }
            .padding(24)
            .navigationTitle(child == nil ? "お子様を追加" : "お子様を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { authViewModel.errorMessage = nil }
            } message: {
                Text(errorText)
            }
            .onChange(of: authViewModel.errorMessage) { _, msg in
                if let msg = msg, !msg.isEmpty {
                    errorText = msg
                    showError = true
                }
            }
            .onAppear {
                if let c = child {
                    name = c.name
                    birthday = c.birthday
                    gender = ChildGender(rawValue: c.gender) ?? .unselected
                }
            }
        }
    }

    private func saveChild() async {
        isSaving = true
        authViewModel.errorMessage = nil
        let newChild = Child(
            child_id: child?.child_id ?? UUID().uuidString,
            name: name,
            birthday: birthday,
            gender: gender.rawValue,
            sort_order: child?.sort_order ?? authViewModel.children.count
        )
        if child == nil {
            await authViewModel.addChild(newChild)
        } else {
            await authViewModel.updateChild(newChild)
        }
        isSaving = false
        if authViewModel.errorMessage == nil {
            dismiss()
        }
    }
}
