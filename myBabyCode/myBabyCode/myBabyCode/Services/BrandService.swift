// =============================================================================
// ファイル名: BrandService.swift
// 役割: Firestoreからブランド・アフィリエイト情報を取得・キャッシュ
// =============================================================================

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Firestore管理のアフィリエイトリンク設定（ブランド別カスタムURL）
struct AffiliateLinkConfig: Codable {
    let id: String
    let brandName: String        // ブランド表示名（BrandEntry.nameと一致）
    let platform: String         // "rakuten", "amazon", "linkshare", "valuecommerce", "a8net"
    let url: String              // 完全なアフィリエイトURL
    let isActive: Bool
    let updatedAt: Date?
}

/// 共通アフィリエイトID設定（プラットフォーム共通）
struct AffiliatePlatformConfig: Codable {
    let rakutenId: String        // 楽天アフィリエイトID
    let amazonTag: String        // Amazon アソシエイトタグ
    let linkshareId: String
    let valuecommercePid: String
    let valuecommerceSid: String
    let a8AffiliateId: String
}

/// 買い物タブの入口リンク
struct ShoppingPortal: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let url: String              // アフィリエイトURL（空なら自動生成）
    let platform: String         // "rakuten", "amazon" 等（アイコン・色判定用）
    let category: String
    let badge: String?
    let order: Int
    let isActive: Bool
    let iconName: String?         // SF Symbols名（カスタムアイコン）
    let themeColor: String?       // HEX色コード（カスタム色）
}

final class BrandService: ObservableObject {
    static let shared = BrandService()
    private init() {}

    // MARK: - Published（Viewが監視可能）
    @Published var remoteBrands: [BrandEntry]?
    @Published var remoteAffiliate: [String: [AffiliateLinkConfig]] = [:]
    @Published var platformConfig: AffiliatePlatformConfig?
    @Published var shoppingPortals: [ShoppingPortal] = []
    @Published var isLoading = false

    /// 利用可能なブランド一覧（Firestore優先、未取得時はローカルフォールバック）
    var brands: [BrandEntry] {
        remoteBrands ?? allBrands
    }

    /// ブランド名 → アフィリエイトリンク配列
    var affiliateMap: [String: [AffiliateLinkConfig]] {
        remoteAffiliate
    }

    /// 共通アフィリエイトIDが設定済みか
    var hasAffiliateConfig: Bool {
        platformConfig != nil
    }

    // MARK: - 一括取得
    func fetchAll() async {
        guard FirebaseAuth.Auth.auth().currentUser != nil else {
            print("[BrandService] fetchAll skipped: not authenticated")
            return
        }
        await MainActor.run { self.isLoading = true }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchBrands() }
            group.addTask { await self.fetchAffiliateLinks() }
            group.addTask { await self.fetchPlatformConfig() }
            group.addTask { await self.fetchShoppingPortals() }
        }
        await MainActor.run { self.isLoading = false }
    }

    // MARK: - ブランド一覧取得
    func fetchBrands() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("brands")
                .whereField("isActive", isEqualTo: true)
                .order(by: "order")
                .getDocuments()

            let entries: [BrandEntry] = snap.documents.compactMap { doc in
                guard let name = doc.data()["name"] as? String,
                      let reading = doc.data()["reading"] as? String else { return nil }
                let order = doc.data()["order"] as? Int ?? 0
                return BrandEntry(
                    id: doc.documentID,
                    name: name,
                    reading: reading,
                    order: order
                )
            }

            await MainActor.run {
                self.remoteBrands = entries.isEmpty ? nil : entries
            }
            print("[BrandService] Fetched \(entries.count) brands from Firestore")
        } catch {
            print("[BrandService] fetchBrands failed: \(error)")
        }
    }

    // MARK: - アフィリエイトリンク取得
    func fetchAffiliateLinks() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("affiliate_links")
                .whereField("isActive", isEqualTo: true)
                .getDocuments()

            var map: [String: [AffiliateLinkConfig]] = [:]
            for doc in snap.documents {
                guard let brandName = doc.data()["brandName"] as? String,
                      let platform = doc.data()["platform"] as? String,
                      let url = doc.data()["url"] as? String else { continue }

                let config = AffiliateLinkConfig(
                    id: doc.documentID,
                    brandName: brandName,
                    platform: platform,
                    url: url,
                    isActive: true,
                    updatedAt: (doc.data()["updatedAt"] as? Timestamp)?.dateValue()
                )
                map[brandName, default: []].append(config)
            }

            await MainActor.run {
                self.remoteAffiliate = map
            }
            print("[BrandService] Fetched \(map.count) affiliate configs")
        } catch {
            print("[BrandService] fetchAffiliateLinks failed: \(error)")
        }
    }

    // MARK: - 共通アフィリエイト設定取得
    func fetchPlatformConfig() async {
        do {
            let doc = try await Firestore.firestore()
                .collection("config")
                .document("affiliate")
                .getDocument()
            guard let data = doc.data() else { return }

            let config = AffiliatePlatformConfig(
                rakutenId: data["rakutenId"] as? String ?? "",
                amazonTag: data["amazonTag"] as? String ?? "",
                linkshareId: data["linkshareId"] as? String ?? "",
                valuecommercePid: data["valuecommercePid"] as? String ?? "",
                valuecommerceSid: data["valuecommerceSid"] as? String ?? "",
                a8AffiliateId: data["a8AffiliateId"] as? String ?? ""
            )

            await MainActor.run {
                self.platformConfig = config
            }
            print("[BrandService] Fetched platform config")
        } catch {
            print("[BrandService] fetchPlatformConfig failed: \(error)")
        }
    }

    // MARK: - 買い物入口リンク取得
    func fetchShoppingPortals() async {
        do {
            let snap = try await Firestore.firestore()
                .collection("shopping_portals")
                .whereField("isActive", isEqualTo: true)
                .order(by: "order")
                .getDocuments()

            let portals: [ShoppingPortal] = snap.documents.compactMap { doc in
                let data = doc.data()
                guard let title = data["title"] as? String,
                      let url = data["url"] as? String else { return nil }
                return ShoppingPortal(
                    id: doc.documentID,
                    title: title,
                    description: data["description"] as? String ?? "",
                    url: url,
                    platform: data["platform"] as? String ?? "",
                    category: data["category"] as? String ?? "all",
                    badge: data["badge"] as? String,
                    order: data["order"] as? Int ?? 0,
                    isActive: data["isActive"] as? Bool ?? true,
                    iconName: data["iconName"] as? String,
                    themeColor: data["themeColor"] as? String
                )
            }

            await MainActor.run {
                self.shoppingPortals = portals
            }
            print("[BrandService] Fetched \(portals.count) shopping portals")
        } catch {
            print("[BrandService] fetchShoppingPortals failed: \(error)")
        }
    }

    // MARK: - ローカルデータをFirestoreへ一括アップロード（初回移行用）
    func uploadDefaultBrands() async {
        let db = Firestore.firestore()
        for (index, entry) in allBrands.enumerated() {
            let data: [String: Any] = [
                "name": entry.name,
                "reading": entry.reading,
                "order": index,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp()
            ]
            do {
                try await db.collection("brands").document(entry.id).setData(data)
            } catch {
                print("[BrandService] Upload failed for \(entry.name): \(error)")
            }
        }
        print("[BrandService] Uploaded \(allBrands.count) brands to Firestore")
    }

    // MARK: - shopping_portals 一括アップロード（初回移行用）
    func uploadDefaultShoppingPortals() async {
        let db = Firestore.firestore()
        let portals: [(id: String, title: String, desc: String, url: String, platform: String, category: String, badge: String?, order: Int, iconName: String?, themeColor: String?)] = [
            ("amazon_baby", "Amazon ベビーストア", "ベビー用品が豊富なAmazonのベビー専門ストア", "https://www.amazon.co.jp/baby", "amazon", "ベビー用品", "おすすめ", 0, nil, nil),
            ("rakuten_baby", "楽天 ベビー・キッズ", "ポイント還元率が高い楽天のベビー・キッズ用品", "https://www.rakuten.co.jp/baby", "rakuten", "ベビー用品", nil, 1, nil, nil),
            ("shimamura", "しまむらオンライン", "プチプラベビー服のしまむら。オンラインで便利に", "https://www.shimamura.gr.jp/", "other", "ベビー服", "プチプラ", 2, nil, nil),
            ("nishimatsuya", "西松屋オンライン", "赤ちゃんのデパート西松屋。定番アイテムが充実", "https://www.nishimatsuya.co.jp/", "other", "ベビー服", "定番", 3, nil, nil),
            ("hm_kids", "H&M キッズ", "おしゃれな北欧デザインの子供服", "https://www2.hm.com/ja_jp/kids.html", "other", "キッズ服", "おしゃれ", 4, nil, nil),
            ("gu_kids", "GU キッズ", "リーズナブルで着やすい子供服", "https://www.gu-global.com/jp/ja/kids", "other", "キッズ服", "リーズナブル", 5, nil, nil),
            ("ifme", "IFME イフミー", "足育を応援する子供靴の専門ブランド", "https://www.ifmeshoes.com/", "other", "靴", "足育", 6, nil, nil),
            ("mikihouse", "MIKI HOUSE", "高品質な日本製子供靴", "https://www.mikihouse.co.jp/", "other", "靴", "日本製", 7, nil, nil),
            ("toysrus", "トイザらス", "おもちゃが豊富なトイザらスオンライン", "https://www.toysrus.co.jp/", "other", "おもちゃ", "豊富", 8, nil, nil),
            ("bornerund", "ボーネルンド", "知育玩具と北欧雑貨のセレクトショップ", "https://www.borneLund.com/", "other", "おもちゃ", "知育", 9, nil, nil),
            ("akachan", "アカチャンホンポ", "ベビー用品が充実する総合専門店", "https://www.akachan.co.jp/", "other", "ベビー用品", "総合", 10, nil, nil),
            ("angeliebe", "エンジェリーベ", "マタニティウェアとベビー用品の通販", "https://www.angeliebe.co.jp/", "other", "マタニティ", "マタニティ", 11, nil, nil),
            ("wacoal_mat", "ワコールマタニティ", "機能性に優れたマタニティインナー", "https://www.wacoal.co.jp/maternity/", "other", "マタニティ", "機能性", 12, nil, nil),
            ("babiesrus", "ベビーザらス", "ベビー用品の大型専門店", "https://www.babiesrus.co.jp/", "other", "ベビー用品", "大型店", 13, nil, nil),
            ("combi", "コンビ公式", "ベビーカーやチャイルドシートの老舗メーカー", "https://www.combi.co.jp/", "other", "ベビー用品", "老舗", 14, nil, nil),
            ("aprica", "アップリカ", "ベビーカーとチャイルドシートの専門メーカー", "https://www.aprica.com/", "other", "ベビー用品", "専門メーカー", 15, nil, nil),
        ]

        for portal in portals {
            let data: [String: Any] = [
                "title": portal.title,
                "description": portal.desc,
                "url": portal.url,
                "platform": portal.platform,
                "category": portal.category,
                "badge": portal.badge as Any,
                "order": portal.order,
                "isActive": true,
                "iconName": portal.iconName as Any,
                "themeColor": portal.themeColor as Any,
                "createdAt": FieldValue.serverTimestamp()
            ]
            do {
                try await db.collection("shopping_portals").document(portal.id).setData(data)
            } catch {
                print("[BrandService] Upload failed for portal \(portal.title): \(error)")
            }
        }
        print("[BrandService] Uploaded \(portals.count) shopping portals to Firestore")
    }

    // MARK: - config/affiliate 空ドキュメント作成（初回移行用）
    func createEmptyAffiliateConfig() async {
        let data: [String: Any] = [
            "rakutenId": "",
            "amazonTag": "",
            "linkshareId": "",
            "valuecommercePid": "",
            "valuecommerceSid": "",
            "a8AffiliateId": "",
            "createdAt": FieldValue.serverTimestamp()
        ]
        do {
            try await Firestore.firestore()
                .collection("config")
                .document("affiliate")
                .setData(data)
            print("[BrandService] Created empty config/affiliate document")
        } catch {
            print("[BrandService] createEmptyAffiliateConfig failed: \(error)")
        }
    }

    // MARK: - アフィリエイトリンク登録（手動更新用）
    func setAffiliateLink(brandName: String, platform: String, url: String) async {
        let docId = "\(brandName)_\(platform)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "　", with: "_")
        let data: [String: Any] = [
            "brandName": brandName,
            "platform": platform,
            "url": url,
            "isActive": true,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            try await Firestore.firestore()
                .collection("affiliate_links")
                .document(docId)
                .setData(data, merge: true)
            print("[BrandService] Set affiliate link for \(brandName) – \(platform)")
        } catch {
            print("[BrandService] setAffiliateLink failed: \(error)")
        }
    }
}
