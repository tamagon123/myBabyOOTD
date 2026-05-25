import Foundation
import FirebaseFirestore

// MARK: - ChildProfile

struct ChildProfile: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String          // ニックネーム（本名非推奨）
    var birthday: Date
    var gender: Int           // 0:未選択 1:男 2:女 3:その他
}

// MARK: - User

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var user_id: String
    var unique_user_id: String?  // ユニークなユーザーID（任意・他ユーザーから識別用）
    var display_name: String?  // 表示名（任意）
    var avatar_id: String
    var avatar_bg_color: String?
    var region_code: String
    var child_birthday: Date
    var child_gender: Int       // 0:未選択 1:男 2:女 3:その他
    var followers_count: Int
    var children: [ChildProfile]?  // 複数子供プロファイル
    var is_profile_complete: Bool? = false  // プロファイル登録完了フラグ
}

// MARK: - Post

struct Post: Identifiable, Codable {
    @DocumentID var id: String?
    var post_id: String
    var user_id: String
    var image_url_front: String?
    var image_url_back: String?
    var child_age_months: Int
    var region_code: String
    var gender_id: Int
    var description: String
    var weather_type: String    // sunny, cloudy, rainy, snowy
    var temp_max: Double
    var temp_min: Double
    var temp_category: String
    var likes_count: Int
    var reports_count: Int
    var is_hidden: Bool
    var created_at: Timestamp

    var item_tags: [PostItemTag]?  // アイテムタグ位置

    // Local helper: poster info loaded separately (not stored in Firestore)
    var posterAvatarId: String?
    var posterAvatarBgColor: String?
    var posterDisplayName: String?
    var posterChildAgeName: String?

    enum CodingKeys: String, CodingKey {
        case post_id, user_id
        case image_url_front, image_url_back
        case child_age_months, region_code, gender_id
        case description, weather_type
        case temp_max, temp_min, temp_category
        case likes_count, reports_count, is_hidden
        case created_at, item_tags
    }
}

// MARK: - PostItem

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case tops        = "トップス"
    case bottoms     = "ボトムス"
    case accessory   = "アクセサリー"
    case outerwear   = "アウター"
    case shoes       = "シューズ"
    case bib         = "スタイ"
    case other       = "その他"
    var id: String { rawValue }
}

struct PostItem: Identifiable, Codable {
    @DocumentID var id: String?
    var item_id: String
    var brand_id: String
    var custom_name: String
    var size_value: Int
    var category: String      // ItemCategory.rawValue
}

// MARK: - PostItemTag

struct PostItemTag: Identifiable, Codable {
    var id: String = UUID().uuidString
    var item_index: Int      // items配列のインデックス
    var x_ratio: Double      // 写真幅に対する横方向比率 (0.0–1.0)
    var y_ratio: Double      // 写真高さに対する縦方向比率 (0.0–1.0)
    var image_side: String   // "front" or "back"
}

// MARK: - Follow

struct Follow: Identifiable, Codable {
    @DocumentID var id: String?
    var follow_id: String
    var follower_id: String
    var following_id: String
    var created_at: Timestamp
}

// MARK: - Enums / Constants

enum ChildGender: Int, CaseIterable, Identifiable {
    case unselected = 0, boy = 1, girl = 2, other = 3
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .unselected: return "未選択"
        case .boy:        return "男の子"
        case .girl:       return "女の子"
        case .other:      return "その他"
        }
    }
    var emoji: String {
        switch self {
        case .boy:   return "👦"
        case .girl:  return "👧"
        default:     return "🧒"
        }
    }
}

enum WeatherType: String, CaseIterable, Identifiable {
    case sunny, cloudy, rainy, snowy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .sunny:  return "晴れ"
        case .cloudy: return "くもり"
        case .rainy:  return "雨"
        case .snowy:  return "雪"
        }
    }
    var emoji: String {
        switch self {
        case .sunny:  return "☀️"
        case .cloudy: return "☁️"
        case .rainy:  return "🌧️"
        case .snowy:  return "❄️"
        }
    }
    var sfSymbol: String {
        switch self {
        case .sunny:  return "sun.max"
        case .cloudy: return "cloud"
        case .rainy:  return "cloud.rain"
        case .snowy:  return "cloud.snow"
        }
    }
}

let clothingSizes: [Int] = [50, 60, 70, 80, 90, 100, 110, 120, 0]

func sizeLabel(_ size: Int) -> String {
    size == 0 ? "フリー" : "\(size)cm"
}

let tempCategories: [(label: String, key: String)] = [
    ("〜9℃", "0-9"),
    ("10〜14℃", "10-14"),
    ("15〜19℃", "15-19"),
    ("20〜24℃", "20-24"),
    ("25℃〜", "25-")
]

// MARK: - Draft

struct PostDraft: Codable {
    var description: String = ""
    var regionIndex: Int = 12
    var weatherType: String = WeatherType.sunny.rawValue
    var tempMax: String = ""
    var tempMin: String = ""
    var items: [DraftItem] = []
    var savedAt: Date = Date()
    var frontImagePath: String? = nil
    var backImagePath: String? = nil
}

struct DraftItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var category: String = ItemCategory.tops.rawValue
    var brandName: String = ""
    var selectedSize: Int = 70
}

let prefectures: [String] = [
    "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島県",
    "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
    "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県",
    "静岡県","愛知県","三重県","滋賀県","京都府","大阪府","兵庫県",
    "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山口県",
    "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県","長崎県",
    "熊本県","大分県","宮崎県","鹿児島県","沖縄県"
]

let avatarEmojis: [String] = [
    "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯",
    "🦁","🐮","🐷","🐸","🐙","🦋","🐝","🦄","🐧","🦩"
]

// MARK: - Avatar Image Names
// Assets.xcassets/AvatarIcons/ に画像を追加したら、ここに名前を1行追記してください
let avatarImageNames: [String] = [
    // 例: "avatar_bear",
    // 例: "avatar_cat",
    "avatar_zou"
]

// MARK: - Stamp Image Names
// Assets.xcassets/StampImages/ に画像を追加したら、ここに名前を1行追記してください
let stampImageNames: [String] = [
    // 例: "stamp_star",
    // 例: "stamp_heart",
    "stamp_zou"
]
