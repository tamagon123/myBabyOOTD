import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedAvatarId: String = "🐶"
    @State private var selectedRegionIndex: Int = 12
    @State private var childBirthday: Date = Date()
    @State private var selectedGender: ChildGender = .unselected
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Avatar selection
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
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedAvatarId == emoji ? Color.indigo : Color.clear, lineWidth: 2)
                                        )
                                        .cornerRadius(14)
                                }
                            }
                        }
                    }

                    Divider()

                    // Child info
                    VStack(alignment: .leading, spacing: 16) {
                        sectionLabel("お子様の情報")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("生年月日").font(.subheadline).foregroundColor(.secondary)
                            DatePicker("", selection: $childBirthday, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ja_JP"))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("性別").font(.subheadline).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(ChildGender.allCases) { g in
                                    Button {
                                        selectedGender = g
                                    } label: {
                                        Text(g.label)
                                            .font(.system(size: 13, weight: .medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 9)
                                            .background(selectedGender == g ? Color.indigo : Color(.systemGray6))
                                            .foregroundColor(selectedGender == g ? .white : .primary)
                                            .cornerRadius(20)
                                    }
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
        selectedAvatarId = user.avatar_id
        childBirthday = user.child_birthday
        selectedGender = ChildGender(rawValue: user.child_gender) ?? .unselected
        if let idx = Int(user.region_code), idx >= 1, idx <= 47 {
            selectedRegionIndex = idx - 1
        }
    }

    private func save() async {
        guard var user = authViewModel.currentUser else { return }
        isSaving = true
        user.avatar_id = selectedAvatarId
        user.child_birthday = childBirthday
        user.child_gender = selectedGender.rawValue
        user.region_code = String(format: "%02d", selectedRegionIndex + 1)
        await authViewModel.saveUserProfile(user)
        isSaving = false
        dismiss()
    }
}
