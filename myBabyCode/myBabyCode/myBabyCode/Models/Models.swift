// =============================================================================
// ファイル名: Models.swift
// 役割: アプリ全体で使用するデータモデル、列挙型、定数の定義
// 説明:
//   このファイルはアプリ内の「データの形」を定義するファイルです。
//   Firestore（データベース）に保存されるドキュメントの構造と対応しています。
//   各structはCodableプロトコルに準拠しており、Firestoreからの取得・保存時に
//   自動的にJSON形式と相互変換されます。
//   Identifiableプロトコルは、SwiftUIのリスト表示で各データを一意に識別するための
//   idプロパティを要求するものです。
// =============================================================================

import Foundation
import FirebaseFirestore

// MARK: - ChildProfile
// 説明: お子様一人分のプロフィール情報。複数の子供を持つ場合、AppUser.children配列に格納されます。

struct ChildProfile: Identifiable, Codable {
    var id: String = UUID().uuidString  // 自動生成される一意ID
    var name: String          // ニックネーム（本名非推奨）
    var birthday: Date        // 生年月日。年齢計算に使用されます。
    var gender: Int           // 0:未選択 1:男の子 2:女の子 3:その他
}

// MARK: - AppUser
// 説明: アプリのユーザーアカウント情報。Firestoreのusersコレクションに1ユーザー1ドキュメントで保存されます。
//       @DocumentIDはFirestoreが自動付与するドキュメントID（= Firebase Auth UID）を表します。

struct AppUser: Identifiable, Codable {
    @DocumentID var id: String?
    var user_id: String                  // Firebase AuthのUID（認証用固有ID）
    var unique_user_id: String?          // ユーザーが自由に設定できる表示ID（@user_name的なもの）
    var display_name: String?          // 画面上に表示される名前
    var avatar_id: String              // アバター画像URL、Assets名、または絵文字文字列
    var avatar_bg_color: String?       // アバター背景色（HEX文字列）
    var region_code: String            // 都道府県コード（2桁文字列。例: "13"=東京都）
    var child_birthday: Date           // 【旧仕様】単一子供用の生年月日。children配列が優先される。
    var child_gender: Int              // 【旧仕様】単一子供用の性別。children配列が優先される。
    var followers_count: Int = 0       // フォロワー数（他ユーザーからのフォロー総数）
    var children: [ChildProfile]?      // 【新仕様】複数の子供プロファイルを配列で保持
    var is_profile_complete: Bool? = false  // 初回プロフィール設定が完了したかのフラグ
    var diary_reminder_enabled: Bool? = false  // 日記リマインダー通知のON/OFF
    var diary_reminder_hour: Int? = 21         // リマインダー通知時刻（時）
    var diary_reminder_minute: Int? = 0        // リマインダー通知時刻（分）
}

// MARK: - Post
// 説明: ユーザーが投稿したコーディネート1件分の情報。Firestoreのpostsコレクションに保存されます。
//       posterAvatarId〜posterChildAgeNameはFirestoreには保存されず、クライアント側で
//       投稿者情報を付加する際に使用する一時的なフィールドです。

struct Post: Identifiable, Codable, @unchecked Sendable {
    @DocumentID var id: String?
    var post_id: String                // 投稿固有のUUID
    var user_id: String                // 投稿者のFirebase Auth UID
    var image_url_front: String?       // 正面写真のFirebase StorageダウンロードURL
    var image_url_back: String?        // 背面写真のFirebase StorageダウンロードURL（任意）
    var child_age_months: Int          // 投稿時の子供の年齢（月数）。検索の絞り込みに使用。
    var region_code: String            // 投稿時の都道府県コード
    var gender_id: Int                 // 投稿時の子供の性別（0〜3）
    var description: String            // 投稿の説明文（コメント）
    var weather_type: String           // 天気種別文字列（"sunny"/"cloudy"/"rainy"/"snowy"）
    var temp_max: Double               // 最高気温（検索・表示用）
    var temp_min: Double               // 最低気温（検索・表示用）
    var temp_category: String          // 気温帯キー（"0-9"/"10-14"など）。検索用。
    var likes_count: Int               // いいねの総数
    var reports_count: Int             // 通報の総数（5件以上で非表示化）
    var is_hidden: Bool                // 運営側・通報により非表示になったか
    var is_calendar_post: Bool?        // カレンダー（日記）からの投稿かどうか
    var created_at: Timestamp          // 投稿日時（Firestoreのサーバータイムスタンプ）

    var item_tags: [PostItemTag]?      // 写真上に配置されたアイテムタグの位置情報
    var stamps: [PostStamp]?           // 写真上に配置されたスタンプの情報（編集時復元用）

    // 以下はFirestoreには保存されないローカル専用フィールド
    // タイムライン表示時に、投稿者情報を付加するために使用
    var posterAvatarId: String?
    var posterAvatarBgColor: String?
    var posterDisplayName: String?
    var posterChildAgeName: String?
    var posterUniqueUserId: String?    // 表示用ユーザーID（@xxx）
    var posterChildGender: Int?        // 子供の性別（ChildGender.rawValue）

    // CodingKeys: Firestoreとの送受信時に含めるフィールドを限定
    // ローカル専用フィールド（poster〜）を除外して送受信する
    enum CodingKeys: String, CodingKey {
        case post_id, user_id
        case image_url_front, image_url_back
        case child_age_months, region_code, gender_id
        case description, weather_type
        case temp_max, temp_min, temp_category
        case likes_count, reports_count, is_hidden
        case is_calendar_post
        case created_at, item_tags
    }
}

// MARK: - PostItem
// 説明: 投稿に紐づく洋服アイテム1件分の情報。Firestoreではposts/{postId}/itemsサブコレクションに保存されます。

// ItemCategory: アイテムの分類。Pickerやチップ選択に使用される。
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
    var item_id: String                // アイテム固有のUUID
    var brand_id: String               // ブランド名（自由入力）
    var custom_name: String            // ユーザーが入力したアイテムの表示名
    var size_value: Int                // サイズ数値（cm）。0は「フリー」を表す。
    var category: String               // ItemCategoryのrawValue文字列
}

// MARK: - PostItemTag
// 説明: 投稿写真上にアイテムタグを配置する際の座標情報。
//       x_ratio/y_ratioは0.0〜1.0の比率値で、どの画面サイズでも正しい位置にタグが表示されるようになっています。

struct PostItemTag: Identifiable, Codable {
    var id: String = UUID().uuidString
    var item_index: Int      // items配列の何番目のアイテムか（0から始まるインデックス）
    var x_ratio: Double      // 写真の左端からの横方向位置（0.0=左端 1.0=右端）
    var y_ratio: Double      // 写真の上端からの縦方向位置（0.0=上端 1.0=下端）
    var image_side: String   // タグを貼る写真の面（"front"=正面 "back"=背面）
}

// MARK: - PostStamp
// 説明: 投稿写真上に配置されたスタンプの情報。Firestoreに保存され編集時に復元可能。
//       スタンプ編集画面で使用される位置・サイズ・回転情報を保持します。

struct PostStamp: Identifiable, Codable {
    var id: String = UUID().uuidString
    var kind_type: String    // "symbol" または "image"
    var kind_value: String   // symbol名（例: "heart.fill"）または画像名
    var x_ratio: Double      // 写真の左端からの横方向位置（0.0=左端 1.0=右端）
    var y_ratio: Double      // 写真の上端からの縦方向位置（0.0=上端 1.0=下端）
    var scale: Double        // スタンプのスケール（1.0がデフォルト）
    var rotation: Double     // 回転角度（ラジアン）
    var image_side: String   // "front"=正面 "back"=背面
    var color_hex: String?   // スタンプの色（HEX文字列、例: "#FF0000"）

    // StampKindへの変換ヘルパー
    var stampKind: StampKind? {
        if kind_type == "symbol" {
            return StampKind.symbol(StampSymbol(rawValue: kind_value) ?? .heart)
        } else if kind_type == "image" {
            return StampKind.image(kind_value)
        }
        return nil
    }
}

// MARK: - Follow
// 説明: ユーザー間のフォロー関係。Firestoreのfollowsコレクションに保存されます。
//       follower_idのユーザーがfollowing_idのユーザーをフォローしていることを表します。

struct Follow: Identifiable, Codable {
    @DocumentID var id: String?
    var follow_id: String      // 関係固有のUUID
    var follower_id: String    // フォローしている側のユーザーID
    var following_id: String   // フォローされている側のユーザーID
    var created_at: Timestamp  // フォローした日時
}

// MARK: - Enums / Constants
// 説明: アプリ内で共通使用される列挙型と定数群。

// ChildGender: 子供の性別を表すEnum。FirestoreにはInt値（rawValue）として保存される。
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

// WeatherType: 天気の種類を表すEnum。投稿時に選択・検索時に絞り込みに使用される。
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
    // sfSymbol: AppleのSF Symbolsアイコン名。SwiftUIでImage(systemName:)として使用。
    var sfSymbol: String {
        switch self {
        case .sunny:  return "sun.max"
        case .cloudy: return "cloud"
        case .rainy:  return "cloud.rain"
        case .snowy:  return "cloud.snow"
        }
    }
}

// clothingSizes: 洋服のサイズ選択肢（cm）。0はフリーサイズを表す。
let clothingSizes: [Int] = [50, 60, 70, 80, 90, 100, 110, 120, 0]

// =============================================================================
// 【関数サマリー】sizeLabel
// 目的: サイズ数値を人間が読める文字列に変換する
// 引数:
//   - size: Int - clothingSizesの要素値
// 戻り値: String - "フリー" または "Xcm"
// 呼び出し元: ItemEntryRow, PostDetailViewなどでサイズ表示時に使用
// =============================================================================
func sizeLabel(_ size: Int) -> String {
    size == 0 ? "フリー" : "\(size)cm"
}

// tempCategories: 気温帯の選択肢。検索絞り込みと投稿時の自動分類に使用される。
// labelは画面上の表示文字列、keyはFirestoreに保存される識別子。
let tempCategories: [(label: String, key: String)] = [
    ("〜9℃", "0-9"),
    ("10〜14℃", "10-14"),
    ("15〜19℃", "15-19"),
    ("20〜24℃", "20-24"),
    ("25℃〜", "25-")
]

// MARK: - CalendarEntry
// 説明: カレンダーに記録する1日分の日記エントリー。
//       Firestoreの calendar_entries/{uid}/entries/{dateKey} に保存されます。
//       dateKeyは "yyyy-MM-dd" 形式の文字列です。

struct CalendarEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var date_key: String          // "yyyy-MM-dd" 形式の日付キー
    var user_id: String           // 作成者のFirebase Auth UID
    var comment: String           // 日記コメント
    var photo_url: String?        // 添付写真のFirebase StorageダウンロードURL
    var weather_type: String?     // "sunny"/"cloudy"/"rainy"/"snowy"（当日の天気）
    var temp_max: Double?         // 最高気温
    var temp_min: Double?         // 最低気温
    var is_public: Bool           // 公開=true / 非公開=false
    var created_at: Timestamp     // 作成日時
    var updated_at: Timestamp     // 最終更新日時
}

// MARK: - CalendarSettings
// 説明: ユーザーのカレンダー設定。Firestoreの users/{uid} ドキュメントに
//       calendar_is_public フィールドとして保存される。

struct CalendarSettings: Codable {
    var is_public: Bool = false   // デフォルトは非公開
}

// MARK: - AppNotification
// 説明: プッシュ通知の履歴。Firestoreの notifications コレクションに保存されます。
//       未読(is_read=false)の数をバッジに表示し、一覧画面で確認できます。

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var user_id: String           // 受信者のUID
    var type: String              // "new_post" / "like" / "follow" / "diary_reminder"
    var title: String             // 通知タイトル
    var body: String              // 通知本文
    var related_id: String?       // 関連ID（投稿者UID/いいねした人/フォロワー/日付キー）
    var post_id: String?          // 投稿ID（new_post/like通知用）
    var is_read: Bool             // 既読フラグ
    var created_at: Timestamp     // 作成日時
}

// MARK: - Draft
// 説明: 新規投稿の下書き情報。UserDefaultsにJSON形式でローカル保存されます。
//       画像はファイルパス文字列で参照し、実体はアプリのDocumentsフォルダに保存されます。

struct PostDraft: Codable {
    var id: String = UUID().uuidString   // 下書きの一意ID（上書き保存に使用）
    var description: String = ""
    var regionIndex: Int = 12            // デフォルトは東京都（prefecturesの12番目）
    var weatherType: String = WeatherType.sunny.rawValue
    var tempMax: String = ""
    var tempMin: String = ""
    var items: [DraftItem] = []
    var savedAt: Date = Date()           // 保存日時（下書き一覧の並び順に使用）
    var frontImagePath: String? = nil    // Documentsフォルダ内の画像ファイルパス
    var backImagePath: String? = nil     // Documentsフォルダ内の画像ファイルパス

    // 既存データ（idフィールドなし）との互換性のためのカスタムデコード
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        self.description = (try? container.decode(String.self, forKey: .description)) ?? ""
        self.regionIndex = (try? container.decode(Int.self, forKey: .regionIndex)) ?? 12
        self.weatherType = (try? container.decode(String.self, forKey: .weatherType)) ?? WeatherType.sunny.rawValue
        self.tempMax = (try? container.decode(String.self, forKey: .tempMax)) ?? ""
        self.tempMin = (try? container.decode(String.self, forKey: .tempMin)) ?? ""
        self.items = (try? container.decode([DraftItem].self, forKey: .items)) ?? []
        self.savedAt = (try? container.decode(Date.self, forKey: .savedAt)) ?? Date()
        self.frontImagePath = try? container.decode(String.self, forKey: .frontImagePath)
        self.backImagePath = try? container.decode(String.self, forKey: .backImagePath)
    }

    // 明示的なメンバーイニシャライザ（カスタムinit(from decoder)を追加したため自動生成されなくなった）
    init(
        id: String = UUID().uuidString,
        description: String = "",
        regionIndex: Int = 12,
        weatherType: String = WeatherType.sunny.rawValue,
        tempMax: String = "",
        tempMin: String = "",
        items: [DraftItem] = [],
        savedAt: Date = Date(),
        frontImagePath: String? = nil,
        backImagePath: String? = nil
    ) {
        self.id = id
        self.description = description
        self.regionIndex = regionIndex
        self.weatherType = weatherType
        self.tempMax = tempMax
        self.tempMin = tempMin
        self.items = items
        self.savedAt = savedAt
        self.frontImagePath = frontImagePath
        self.backImagePath = backImagePath
    }
}

struct DraftItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var category: String = ItemCategory.tops.rawValue
    var brandName: String = ""
    var selectedSize: Int = 70           // デフォルトサイズ70cm
}

// prefectures: 日本の47都道府県名の配列。Pickerや検索UIに使用される。
let prefectures: [String] = [
    "北海道","青森県","岩手県","宮城県","秋田県","山形県","福島県",
    "茨城県","栃木県","群馬県","埼玉県","千葉県","東京都","神奈川県",
    "新潟県","富山県","石川県","福井県","山梨県","長野県","岐阜県",
    "静岡県","愛知県","三重県","滋賀県","京都府","大阪府","兵庫県",
    "奈良県","和歌山県","鳥取県","島根県","岡山県","広島県","山口県",
    "徳島県","香川県","愛媛県","高知県","福岡県","佐賀県","長崎県",
    "熊本県","大分県","宮崎県","鹿児島県","沖縄県"
]

// avatarEmojis: アバターとして使用できる絵文字の候補リスト。
let avatarEmojis: [String] = [
    "🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐨","🐯",
    "🦁","🐮","🐷","🐸","🐙","🦋","🐝","🦄","🐧","🦩"
]

// MARK: - Avatar Image Names
// 説明: Assets.xcassets/AvatarIcons/ に画像を追加したら、ここに名前を1行追記してください。
//       ProfileSetupViewやEditProfileViewのアバター選択グリッドに自動的に表示されます。
let avatarImageNames: [String] = [
    // 例: "avatar_bear",
    // 例: "avatar_cat",
    "zou",
    "inu",
    "kirin",
    "neko",
    "saru",
    "panda",
    "tori"
    
]

// MARK: - Stamp Image Names
// 説明: Assets.xcassets/StampImages/ に画像を追加したら、ここに名前を1行追記してください。
//       PhotoEditorViewのスタンプパレットに自動的に表示されます。
let stampImageNames: [String] = [
    // 例: "stamp_star",
    // 例: "stamp_heart",
    "face1a",
    "face1b",
    "face1c",
    "face2a",
    "face2b",
    "face2c",
    "face3a",
    "face3b",
    "face3c"
]
