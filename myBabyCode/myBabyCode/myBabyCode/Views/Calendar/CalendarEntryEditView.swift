// =============================================================================
// ファイル名: CalendarEntryEditView.swift
// 役割: カレンダー日記の新規作成・編集画面
// =============================================================================

import SwiftUI
import FirebaseAuth

struct CalendarEntryEditView: View {
    let date: Date
    @ObservedObject var vm: CalendarViewModel
    let uid: String
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    private var dateKey: String { CalendarView.dateKey(for: date) }
    private var existingEntry: CalendarEntry? { vm.entries[dateKey] }

    @State private var comment: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showPhotoSourceSheet = false
    @State private var isFetchingWeather = false
    @State private var showDeleteConfirm = false
    @State private var isSaving = false

    private var regionCode: String {
        authViewModel.currentUser?.region_code ?? "13"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 日付ヘッダー
                    dateTitleSection

                    // 天気情報
                    weatherSection

                    // 日記コメント
                    commentSection

                    // 写真
                    photoSection

                    // 削除ボタン（既存エントリーのみ）
                    if existingEntry != nil {
                        deleteSection
                    }
                }
                .padding()
            }
            .background(Color.ecruBackground.ignoresSafeArea())
            .navigationTitle("日記を記録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("保存")
                                .fontWeight(.semibold)
                                .foregroundColor(.accentRed)
                        }
                    }
                    .disabled(isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .confirmationDialog("写真を選択", isPresented: $showPhotoSourceSheet, titleVisibility: .visible) {
                Button("カメラで撮影") {
                    imagePickerSourceType = .camera
                    showImagePicker = true
                }
                Button("ライブラリから選択") {
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
                }
                if selectedImage != nil || existingEntry?.photo_url != nil {
                    Button("写真を削除", role: .destructive) {
                        selectedImage = nil
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePickerView(sourceType: imagePickerSourceType) { img in
                    selectedImage = img
                }
            }
            .alert("この日記を削除しますか？", isPresented: $showDeleteConfirm) {
                Button("削除する", role: .destructive) {
                    Task {
                        await vm.deleteEntry(uid: uid, dateKey: dateKey)
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
            .onAppear {
                if let entry = existingEntry {
                    comment = entry.comment
                }
                if existingEntry?.weather_type == nil {
                    Task { await fetchWeather() }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var dateTitleSection: some View {
        let fmt = DateFormatter()
        let _ = { fmt.dateFormat = "yyyy年M月d日（E）"; fmt.locale = Locale(identifier: "ja_JP") }()
        return Text(fmt.string(from: date))
            .font(.appFont(.bold, size: 18))
            .foregroundColor(.primary)
    }

    private var weatherSection: some View {
        let entry = existingEntry
        return VStack(alignment: .leading, spacing: 8) {
            Text("天気・気温")
                .font(.appFont(.medium, size: 13))
                .foregroundColor(Color(.systemGray))

            HStack(spacing: 12) {
                if let w = entry?.weather_type.flatMap({ WeatherType(rawValue: $0) }) {
                    Label {
                        Text(w.label)
                    } icon: {
                        Text(w.emoji)
                    }
                    .font(.appFont(.regular, size: 15))
                }
                if let max = entry?.temp_max, let min = entry?.temp_min {
                    Text("最高 \(Int(max.rounded()))° / 最低 \(Int(min.rounded()))°")
                        .font(.appFont(.medium, size: 14))
                        .foregroundColor(Color(.systemGray))
                }
                Spacer()
                Button {
                    Task { await fetchWeather() }
                } label: {
                    HStack(spacing: 4) {
                        if isFetchingWeather {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(entry?.weather_type == nil ? "取得" : "更新")
                    }
                    .font(.appFont(.regular, size: 12))
                    .foregroundColor(.accentBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentBlue.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(isFetchingWeather)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日記コメント")
                .font(.appFont(.medium, size: 13))
                .foregroundColor(Color(.systemGray))
            ZStack(alignment: .topLeading) {
                TextEditor(text: $comment)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(12)
                if comment.isEmpty {
                    Text("今日のコーデや出来事を記録しましょう...")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(Color(.systemGray3))
                        .padding(.top, 16)
                        .padding(.leading, 12)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("写真")
                .font(.appFont(.medium, size: 13))
                .foregroundColor(Color(.systemGray))
            Button {
                showPhotoSourceSheet = true
            } label: {
                ZStack {
                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(12)
                    } else if let urlStr = existingEntry?.photo_url, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color(.systemGray5)
                        }
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .frame(height: 100)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "camera")
                                        .font(.appFont(.regular, size: 24))
                                    Text("写真を追加（任意）")
                                        .font(.appFont(.regular, size: 13))
                                }
                                .foregroundColor(Color(.systemGray3))
                            )
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirm = true
        } label: {
            HStack {
                Spacer()
                Label("この日記を削除", systemImage: "trash")
                    .font(.appFont(.medium, size: 14))
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func fetchWeather() async {
        isFetchingWeather = true
        if let result = await WeatherService.shared.fetchHistorical(regionCode: regionCode, date: date) {
            await vm.updateWeather(uid: uid, dateKey: dateKey, weather: result)
        }
        isFetchingWeather = false
    }

    private func save() async {
        isSaving = true
        let ok = await vm.saveEntry(
            uid: uid,
            dateKey: dateKey,
            comment: comment,
            image: selectedImage,
            regionCode: regionCode
        )
        isSaving = false
        if ok { dismiss() }
    }
}
