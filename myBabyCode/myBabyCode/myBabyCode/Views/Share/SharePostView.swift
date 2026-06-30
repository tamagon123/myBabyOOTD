//
//  SharePostView.swift
//  myBabyCode
//
//  Created by s-tamaki on 2025/01/01.
//

import SwiftUI
import UIKit
import FirebaseCore
import FirebaseFirestore

struct SharePostView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItems: ShareableItems = ShareableItems()
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var showSaveAlert = false
    @State private var postItems: [PostItem] = []     // Firestoreから取得した投稿アイテム
    @State private var itemsLoaded = false            // アイテムがロード済みか
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // プレビュー表示
                    previewSection
                    
                    // 選択項目
                    selectionSection
                    
                    // 共有ボタン
                    shareButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = generatedImage {
                ShareSheet(items: [image])
            }
        }
        .alert("保存完了", isPresented: $showSaveAlert) {
            Button("OK") { }
        } message: {
            Text("画像をフォトライブラリに保存しました")
        }
        .onAppear {
            if !itemsLoaded {
                loadItems()
            }
        }
    }
    
    // MARK: - アイテムデータ取得
    private func loadItems() {
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return }
        let db = Firestore.firestore()
        Task {
            do {
                let snap = try await db.collection("posts").document(postId).collection("items")
                    .order(by: "item_id")
                    .getDocuments()
                
                let items = snap.documents.compactMap { doc -> PostItem? in
                    try? doc.data(as: PostItem.self)
                }
                
                await MainActor.run {
                    self.postItems = items
                    self.itemsLoaded = true
                }
            } catch {
                print("[ERROR] Failed to load items: \(error)")
            }
        }
    }
    
    // MARK: - プレビュー表示
    @ViewBuilder
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("プレビュー")
                .font(.appFont(.bold, size: 18))
                .foregroundColor(.primary)
            
            previewContent
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var previewContent: some View {
        ZStack {
            // 薄い生成り色の背景（実際の出力と同じ）
            previewBackground
            
            // プレビューコンテンツ（実際の出力仕様に完全に合わせる）
            previewMainContent
        }
    }
    
    private var previewBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.98, green: 0.97, blue: 0.95))
            .frame(width: 180, height: 320) // 1080x1920の1/6サイズ
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    @ViewBuilder
    private var previewMainContent: some View {
        VStack(spacing: 2) {
            // アプリアイコン（最上部中央 - フル画像）
            Group {
                if let logoImage = UIImage(named: "logo") {
                    Image(uiImage: logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 45, height: 15)
                        .clipped()
                } else {
                    // アイコンが読み込めない場合の代替表示
                    Text("myBaby")
                        .font(.appFont(.bold, size: 12))
                        .foregroundColor(.blue)
                        .frame(width: 45, height: 15)
                }
            }
            
            Spacer().frame(height: 8)
            
            // ユーザー情報セクション
            HStack(spacing: 2) {
                // アバター画像（実際の画像を取得）
                previewAvatarImage
                
                // ユーザー情報
                previewUserInfo
            }
            
            Spacer().frame(height: 4)
            
            // メイン写真（角丸 - 実際のサイズ比率）
            previewMainPhoto
            
            Spacer().frame(height: 4)
            
            // タグとブランド名
            if selectedItems.showTags {
                let tagTexts = getPreviewTagTexts()
                
                if !tagTexts.isEmpty {
                    Text(tagTexts)
                        .font(.appFont(.regular, size: 6))
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .frame(maxWidth: 160, alignment: .leading)
                }
            }
            
            Spacer().frame(height: 2)
            
            // コメント（角丸背景 - 写真と同じ横幅）
            if selectedItems.showComment && !post.description.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.description)
                        .font(.appFont(.regular, size: 6))
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .frame(maxWidth: 120, alignment: .leading) // 写真と同じ幅
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(3) // 写真と同じ角丸
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .frame(maxWidth: 140, alignment: .leading)
            }
            
            Spacer()
        }
    }
    
    private var previewAvatarImage: some View {
        Group {
            if let avatarId = post.posterAvatarId {
                if avatarId.hasPrefix("https://") {
                    AsyncImage(url: URL(string: avatarId)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                } else {
                    Image(avatarId)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        .background(Color.gray.opacity(0.3))
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text("👤")
                            .font(.system(size: 8))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    private var previewUserInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(post.posterDisplayName ?? "ユーザー")
                .font(.appFont(.bold, size: 8))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            HStack(spacing: 1) {
                if selectedItems.showChildNickname {
                    Text(post.posterChildAgeName ?? "赤ちゃん")
                        .font(.appFont(.regular, size: 6))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if selectedItems.showRegion {
                    Text(getRegionName(from: post.region_code))
                        .font(.appFont(.regular, size: 6))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                if selectedItems.showPostDate {
                    Text(formatDate(post.created_at.dateValue()))
                        .font(.appFont(.regular, size: 6))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: 160)
    }
    
    private var previewMainPhoto: some View {
        Group {
            if let url = post.image_url_front {
                AsyncImage(url: URL(string: url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit) // 比率を維持
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 140, height: 168) // 最大サイズ
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    // 天気バッジ（左上）- タイムラインと同じ背景色
                    previewWeatherBadge
                )
                .overlay(
                    // アイテムタグドットとブランド名（タイムラインと同じ）
                    previewItemTags
                )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 168)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
    
    private var previewWeatherBadge: some View {
        Group {
            if selectedItems.showWeather {
                HStack(spacing: 1) {
                    Image(getWeatherIcon(from: post.weather_type))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 5, height: 5)
                    Text("\(Int(post.temp_max))°/\(Int(post.temp_min))°")
                        .font(.appFont(.bold, size: 5))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 1)
                .background(getWeatherBgColor(for: post.weather_type))
                .cornerRadius(1)
                .offset(x: -60, y: -75)
            }
        }
    }
    
    private var previewItemTags: some View {
        Group {
            if selectedItems.showTags, let itemTags = post.item_tags {
                ForEach(Array(itemTags.enumerated()), id: \.offset) { index, tag in
                    if tag.image_side == "front" {
                        previewItemTagView(tag: tag)
                    }
                }
            }
        }
    }
    
    private func previewItemTagView(tag: PostItemTag) -> some View {
        HStack(spacing: 1) {
            previewItemTagDot
            
            // ブランド名ラベル
            if itemsLoaded && tag.item_index < postItems.count {
                previewBrandLabel(tag: tag)
            }
        }
        .offset(
            x: -70 + CGFloat(tag.x_ratio) * 140,
            y: -84 + CGFloat(tag.y_ratio) * 168
        )
    }
    
    private var previewItemTagDot: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 4, height: 4)
            .overlay(
                Circle()
                    .stroke(Color.red, lineWidth: 0.8)
            )
    }
    
    private func previewBrandLabel(tag: PostItemTag) -> some View {
        let item = postItems[tag.item_index]
        let labelText = getLabelText(for: item)
        
        return Text(labelText)
            .font(.appFont(.bold, size: 4))
            .foregroundColor(.white)
            .padding(.horizontal, 1)
            .padding(.vertical, 0.5)
            .background(Color.black.opacity(0.8))
            .cornerRadius(1)
    }
    
    private func getLabelText(for item: PostItem) -> String {
        if item.brand_id.lowercased() == "custom" {
            // brand_idがcustomの場合はcustom_nameのみ表示
            return item.custom_name.isEmpty ? "不明" : item.custom_name
        } else {
            // 通常の場合はbrand_id + custom_name
            let brandName = item.brand_id.isEmpty ? "不明" : item.brand_id
            let itemName = (item.custom_name.isEmpty || item.custom_name.lowercased() == "custom") ? "" : " \(item.custom_name)"
            return "\(brandName)\(itemName)"
        }
    }
    
    // MARK: - 選択項目
    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("共有する項目を選択")
                .font(.appFont(.bold, size: 18))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ToggleItem(title: "投稿日", isOn: $selectedItems.showPostDate)
                ToggleItem(title: "天気・気温", isOn: $selectedItems.showWeather)
                ToggleItem(title: "ユーザー表示名", isOn: $selectedItems.showUserName)
                ToggleItem(title: "子供のニックネーム", isOn: $selectedItems.showChildNickname)
                ToggleItem(title: "地域", isOn: $selectedItems.showRegion)
                ToggleItem(title: "タグとブランド名", isOn: $selectedItems.showTags)
                ToggleItem(title: "コメント", isOn: $selectedItems.showComment)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 共有ボタン
    private var shareButton: some View {
        Button(action: {
            generateShareImage()
        }) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(isGenerating ? "生成中..." : "画像を生成して共有")
                    .font(.appFont(.bold, size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
            .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isGenerating)
        .padding(.horizontal)
    }
    
    // MARK: - 画像生成
    private func generateShareImage() {
        isGenerating = true
        
        Task {
            await generateImageWithNewMethod()
        }
    }
    
    private func generateImageWithNewMethod() async {
        let generator = ShareImageGenerator()
        
        if let image = await generator.createInstagramStoryImage(post: post) {
            self.generatedImage = image
            self.isGenerating = false
            
            if image.size.width > 0 && image.size.height > 0 {
                // 共有シートを表示
                self.showShareSheet = true
                
                // 画像も保存
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                self.showSaveAlert = true
            } else {
                // 画像生成失敗
                print("画像生成失敗: サイズが0")
            }
        } else {
            self.isGenerating = false
            print("画像生成失敗: nilが返されました")
        }
    }
    
    private func loadItemsAsync() async {
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return }
        let db = Firestore.firestore()
        
        do {
            let snap = try await db.collection("posts").document(postId).collection("items")
                .order(by: "item_id")
                .getDocuments()
            
            let items = snap.documents.compactMap { doc -> PostItem? in
                try? doc.data(as: PostItem.self)
            }
            
            await MainActor.run {
                self.postItems = items
                self.itemsLoaded = true
            }
        } catch {
            print("[ERROR] Failed to load items: \(error)")
        }
    }
    
    // 時刻フォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d H:mm"
        return formatter.string(from: date)
    }
    
    // 地域名取得
    private func getRegionName(from code: String) -> String {
        let regions: [String: String] = [
            "hokkaido": "北海道", "aomori": "青森", "iwate": "岩手", "miyagi": "宮城",
            "akita": "秋田", "yamagata": "山形", "fukushima": "福島", "ibaraki": "茨城",
            "tochigi": "栃木", "gunma": "群馬", "saitama": "埼玉", "chiba": "千葉",
            "tokyo": "東京", "kanagawa": "神奈川", "niigata": "新潟", "toyama": "富山",
            "ishikawa": "石川", "fukui": "福井", "yamanashi": "山梨", "nagano": "長野",
            "gifu": "岐阜", "shizuoka": "静岡", "aichi": "愛知", "mie": "三重",
            "shiga": "滋賀", "kyoto": "京都", "osaka": "大阪", "hyogo": "兵庫",
            "nara": "奈良", "wakayama": "和歌山", "tottori": "鳥取", "shimane": "島根",
            "okayama": "岡山", "hiroshima": "広島", "yamaguchi": "山口", "tokushima": "徳島",
            "kagawa": "香川", "ehime": "愛媛", "kochi": "高知", "fukuoka": "福岡",
            "saga": "佐賀", "nagasaki": "長崎", "kumamoto": "熊本", "oita": "大分",
            "miyazaki": "宮崎", "kagoshima": "鹿児島", "okinawa": "沖縄"
        ]
        return regions[code.lowercased()] ?? code
    }
    
    // プレビュー用の天気背景色
    private func getWeatherBgColor(for weatherType: String) -> Color {
        switch weatherType.lowercased() {
        case "sunny", "晴れ":
            return Color.orange.opacity(0.5)
        case "cloudy", "曇り":
            return Color.gray.opacity(0.5)
        case "rainy", "雨":
            return Color.blue.opacity(0.5)
        case "snowy", "雪":
            return Color.cyan.opacity(0.5)
        default:
            return Color.black.opacity(0.5)
        }
    }
    
    // プレビュー用のタグテキスト
    private func getPreviewTagTexts() -> String {
        if let itemTags = post.item_tags, !itemTags.isEmpty {
            return "アイテムタグ \(itemTags.count)点"
        }
        return ""
    }
    
    // 天気アイコン
    private func getWeatherIcon(from weatherType: String) -> String {
        switch weatherType.lowercased() {
        case "sunny", "晴れ": return "weather_sunny"
        case "cloudy", "曇り": return "weather_cloudy"
        case "rainy", "雨": return "weather_rainy"
        case "snowy", "雪": return "weather_snowy"
        default: return "weather_default"
        }
    }
}

// 共有可能な項目
struct ShareableItems {
    var showPostDate: Bool = true
    var showWeather: Bool = true
    var showUserName: Bool = true
    var showChildNickname: Bool = true
    var showRegion: Bool = true
    var showTags: Bool = true
    var showComment: Bool = true
}

// トグルアイテム
struct ToggleItem: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.appFont(.regular, size: 16))
                .foregroundColor(.primary)
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(.vertical, 4)
    }
}

// 共有シート
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


let dummyPost = Post(
    id: "preview",
    post_id: "preview_post_id",
    user_id: "preview",
    image_url_front: "https://via.placeholder.com/960x1152",
    image_url_back: nil,
    child_age_months: 12,
    region_code: "tokyo",
    gender_id: 1,
    description: "これはプレビュー用の投稿です。今日の服装を共有します。",
    weather_type: "sunny",
    temp_max: 25.0,
    temp_min: 18.0,
    temp_category: "20-24",
    likes_count: 0,
    reports_count: 0,
    is_hidden: false,
    is_calendar_post: false,
    created_at: Timestamp(date: Date()),
    item_tags: [],
    stamps: [],
    posterAvatarId: "zou",
    posterAvatarBgColor: "#FFEEBA",
    posterDisplayName: "テストユーザー",
    posterChildAgeName: "1歳",
    posterUniqueUserId: "preview_user",
    posterChildGender: 1
)

#Preview {
    SharePostView(post: dummyPost)
}
