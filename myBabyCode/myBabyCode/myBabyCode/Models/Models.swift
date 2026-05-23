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
    var display_name: String?  // 表示名（任意）
    var avatar_id: String
    var region_code: String
    var child_birthday: Date
    var child_gender: Int       // 0:未選択 1:男 2:女 3:その他
    var followers_count: Int
    var children: [ChildProfile]?  // 複数子供プロファイル
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

    // Local helper: poster's avatar_id loaded separately
    var posterAvatarId: String?
    var posterChildAgeName: String?
}

// MARK: - PostItem

enum ItemCategory: String, CaseIterable, Identifiable, Codable {
    case tops        = "トップス"
    case bottoms     = "ボトムス"
    case accessory   = "アクセサリー"
    case outerwear   = "アウター"
    case shoes       = "シューズ"
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
}

let clothingSizes: [Int] = [50, 60, 70, 80, 90, 100, 110, 120]

let tempCategories: [(label: String, key: String)] = [
    ("〜9℃", "0-9"),
    ("10〜14℃", "10-14"),
    ("15〜19℃", "15-19"),
    ("20〜24℃", "20-24"),
    ("25℃〜", "25-")
]

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
