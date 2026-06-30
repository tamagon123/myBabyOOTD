// =============================================================================
// ファイル名: PurchaseItem.swift
// 役割: 購入品データモデル
// 説明:
//   カレンダー機能に追加する購入品登録機能のデータモデルです。
//   購入品情報（名前、価格、場所、写真、ひとこと）を管理します。
// =============================================================================

import Foundation

struct PurchaseItem: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let date: Date
    let name: String
    let price: Double?
    let location: String?
    let photoUrl: String?
    let memo: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        date: Date,
        name: String,
        price: Double? = nil,
        location: String? = nil,
        photoUrl: String? = nil,
        memo: String? = nil,
        isPublic: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.name = name
        self.price = price
        self.location = location
        self.photoUrl = photoUrl
        self.memo = memo
        self.isPublic = isPublic
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // Firestore用の辞書変換
    var toDictionary: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "userId": userId,
            "date": Timestamp.from(date: date),
            "name": name,
            "price": price as Any,
            "location": location as Any,
            "photoUrl": photoUrl as Any,
            "memo": memo as Any,
            "isPublic": isPublic,
            "createdAt": Timestamp.from(date: createdAt),
            "updatedAt": Timestamp.from(date: updatedAt)
        ]
        return dict
    }
    
    // Firestoreからの初期化
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["userId"] as? String,
              let dateTimestamp = dictionary["date"] as? Timestamp,
              let name = dictionary["name"] as? String,
              let isPublic = dictionary["isPublic"] as? Bool,
              let createdAtTimestamp = dictionary["createdAt"] as? Timestamp,
              let updatedAtTimestamp = dictionary["updatedAt"] as? Timestamp else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.date = dateTimestamp.dateValue()
        self.name = name
        self.price = dictionary["price"] as? Double
        self.location = dictionary["location"] as? String
        self.photoUrl = dictionary["photoUrl"] as? String
        self.memo = dictionary["memo"] as? String
        self.isPublic = isPublic
        self.createdAt = createdAtTimestamp.dateValue()
        self.updatedAt = updatedAtTimestamp.dateValue()
    }
    
    // 価格表示用
    var priceText: String {
        guard let price = price else { return "" }
        return "¥\(Int(price).formattedWithSeparator)"
    }
    
    // 日付表示用
    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

// MARK: - 拡張
extension Int {
    var formattedWithSeparator: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Firestore Timestampヘルパー
import FirebaseFirestore

extension Timestamp {
    static func from(date: Date) -> Timestamp {
        return Timestamp(seconds: Int64(date.timeIntervalSince1970), nanoseconds: 0)
    }
}
