// =============================================================================
// ファイル名: PurchaseItemRegistrationView.swift
// 役割: 購入品登録画面
// 説明:
//   カレンダーから呼び出される購入品登録画面です。
//   複数の購入品を一度に登録でき、写真、価格、場所、ひとことを記録できます。
// =============================================================================

import SwiftUI
import PhotosUI
import Firebase
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth

struct PurchaseItemRegistrationView: View {
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PurchaseItemInput] = []
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private var isSubscribed: Bool { SubscriptionManager.shared.isSubscribed }
    private var canAddToday: Bool { isSubscribed || Calendar.current.isDateInYesterday(selectedDate) }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 日付表示
                    dateHeader
                    
                    // 登録アイテムリスト
                    itemsList
                    
                    // アイテム追加ボタン
                    addItemButton
                    
                    // 保存ボタン
                    saveButton
                }
                .padding()
            }
            .navigationTitle("購入品を登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .alert("確認", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            if !canAddToday {
                alertMessage = "今日の購入品登録はプレミアムプランのみ利用できます。"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - 日付ヘッダー
    private var dateHeader: some View {
        VStack(spacing: 8) {
            Text(formatDate(selectedDate))
                .font(.appFont(.bold, size: 20))
                .foregroundColor(.primary)
            
            Text("の購入品を登録")
                .font(.appFont(.regular, size: 16))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - アイテムリスト
    private var itemsList: some View {
        VStack(spacing: 12) {
            ForEach(items.indices, id: \.self) { index in
                PurchaseItemInputView(
                    item: $items[index],
                    onDelete: {
                        items.remove(at: index)
                    }
                )
            }
            
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bag")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("購入品がまだ登録されていません")
                        .font(.appFont(.regular, size: 16))
                        .foregroundColor(.secondary)
                    
                    Text("下のボタンから追加してください")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - アイテム追加ボタン
    private var addItemButton: some View {
        Button(action: {
            items.append(PurchaseItemInput())
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("購入品を追加")
            }
            .font(.appFont(.medium, size: 16))
            .foregroundColor(.accentBlue)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.accentBlue.opacity(0.1))
            .cornerRadius(12)
        }
        .disabled(items.count >= 10) // 最大10個まで
    }
    
    // MARK: - 保存ボタン
    private var saveButton: some View {
        Button(action: saveItems) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("保存する")
            }
            .font(.appFont(.bold, size: 16))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isLoading || items.isEmpty ? Color.gray : Color.accentBlue)
            .cornerRadius(12)
        }
        .disabled(isLoading || items.isEmpty)
    }
    
    // MARK: - 保存処理
    private func saveItems() {
        guard !items.isEmpty else { return }
        
        isLoading = true
        
        Task {
            do {
                let savedItems = try await savePurchaseItems()
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = "\(savedItems.count)件の購入品を保存しました"
                    showAlert = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "保存に失敗しました: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func savePurchaseItems() async throws -> [PurchaseItem] {
        guard let userId = FirebaseAuth.Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "ユーザーが認証されていません"])
        }
        
        let db = Firestore.firestore()
        var savedItems: [PurchaseItem] = []
        
        for item in items {
            // 写真アップロード
            var photoUrl: String?
            if let imageData = item.photoData {
                photoUrl = try await uploadPhoto(imageData: imageData, userId: userId, date: selectedDate)
            }
            
            // 購入品作成
            let purchaseItem = PurchaseItem(
                userId: userId,
                date: selectedDate,
                name: item.name,
                price: item.price.isEmpty ? nil : Double(item.price.replacingOccurrences(of: ",", with: "")),
                location: item.location.isEmpty ? nil : item.location,
                photoUrl: photoUrl,
                memo: item.memo.isEmpty ? nil : item.memo,
                isPublic: item.isPublic
            )
            
            // Firestoreに保存
            let docRef = db.collection("users").document(userId)
                .collection("purchaseItems").document(purchaseItem.id)
            
            try await docRef.setData(purchaseItem.toDictionary)
            savedItems.append(purchaseItem)
        }
        
        return savedItems
    }
    
    private func uploadPhoto(imageData: Data, userId: String, date: Date) async throws -> String {
        let storageRef = Storage.storage().reference()
        let fileName = "\(dateFormatter.string(from: date))_\(UUID().uuidString).jpg"
        let imageRef = storageRef.child("users/\(userId)/purchaseItems/\(fileName)")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        let _ = try await imageRef.putData(imageData, metadata: metadata)
        return try await imageRef.downloadURL().absoluteString
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

// MARK: - 購入品入力データ
struct PurchaseItemInput: Identifiable {
    let id = UUID()
    var name: String = ""
    var price: String = ""
    var location: String = ""
    var photoData: Data?
    var memo: String = ""
    var isPublic: Bool = false
    private var _selectedImage: Any? // 内部保存用
    
    @available(iOS 16.0, *)
    var selectedImage: PhotosPickerItem? {
        get { return _selectedImage as? PhotosPickerItem }
        set { _selectedImage = newValue }
    }
}

// MARK: - 購入品入力ビュー
struct PurchaseItemInputView: View {
    @Binding var item: PurchaseItemInput
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // ヘッダー（削除ボタン）
            HStack {
                Text("購入品 \(item.id.uuidString.prefix(4))")
                    .font(.appFont(.medium, size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 24))
                }
            }
            
            // 写真
            photoSection
            
            // 基本情報
            VStack(spacing: 12) {
                TextField("商品名", text: $item.name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.appFont(.regular, size: 16))
                
                TextField("価格（例：1,000）", text: $item.price)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.appFont(.regular, size: 16))
                    .keyboardType(.numberPad)
                
                TextField("購入場所", text: $item.location)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.appFont(.regular, size: 16))
                
                if #available(iOS 16.0, *) {
                    TextField("ひとこと（任意）", text: $item.memo, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.appFont(.regular, size: 16))
                        .lineLimit(3)
                } else {
                    TextField("ひとこと（任意）", text: $item.memo)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.appFont(.regular, size: 16))
                        .lineLimit(3)
                }
            }
            
            // 公開設定
            Toggle("この購入品を公開する", isOn: $item.isPublic)
                .font(.appFont(.regular, size: 14))
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4)
    }
    
    // MARK: - 写真セクション
    private var photoSection: some View {
        Group {
            if #available(iOS 16.0, *) {
                PhotosPicker(selection: Binding(
                    get: { item.selectedImage },
                    set: { newValue in
                        if #available(iOS 16.0, *) {
                            item.selectedImage = newValue
                        }
                    }
                ), matching: .images, photoLibrary: .shared()) {
                    photoContent
                }
                .onChange(of: item.selectedImage) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            item.photoData = data
                        }
                    }
                }
            } else {
                // iOS 16.0未満の場合はシンプルなボタン表示
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 32))
                        .foregroundColor(.accentBlue)
                    
                    Text("写真を追加 (iOS 16.0+)")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.accentBlue)
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .background(Color.accentBlue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    @ViewBuilder
    private var photoContent: some View {
        if let photoData = item.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentBlue, lineWidth: 2)
                )
        } else {
            VStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.system(size: 32))
                    .foregroundColor(.accentBlue)
                
                Text("写真を追加")
                    .font(.appFont(.regular, size: 14))
                    .foregroundColor(.accentBlue)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .background(Color.accentBlue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

#Preview {
    PurchaseItemRegistrationView(selectedDate: Date())
}
