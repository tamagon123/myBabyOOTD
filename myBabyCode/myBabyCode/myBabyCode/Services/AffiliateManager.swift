// =============================================================================
// ファイル名: AffiliateManager.swift
// 役割: アフィリエイトリンク（楽天・Amazon）の生成・管理
// 説明:
//   投稿に登録されたブランド名やアイテム情報をもとに、楽天市場・Amazonの
//   商品検索ページへのアフィリエイトリンクを動的に生成します。
//   アプリ公開後に楽天・Amazonのアフィリエイトプログラムに登録し、
//   取得したIDをこのファイルの定数に設定するだけで機能が有効になります。
//
//   【セットアップ手順】
//   1. 楽天アフィリエイト: https://affiliate.rakuten.co.jp/ に登録
//      → affiliateIdRakuten に取得したアフィリエイトID（例: "abc123-20"）を設定
//   2. Amazon アソシエイト: https://affiliate.amazon.co.jp/ に登録
//      → associateTagAmazon に取得したアソシエイトタグを設定
// =============================================================================

import Foundation

// MARK: - アフィリエイト設定
// アプリ公開後に各プログラムに登録してIDを設定してください

private enum AffiliateConfig {
    // === 楽天アフィリエイト ===
    // https://affiliate.rakuten.co.jp/ で取得
    // 形式例: "1a2b3c4d.5e6f7g8i.9j0k1l2m.1n2o3p4q" または "abc123-20"
    static let affiliateIdRakuten: String = ""

    // === Amazon アソシエイト ===
    // https://affiliate.amazon.co.jp/ で取得
    // 形式例: "yourtag-22"
    static let associateTagAmazon: String = ""

    // === リンクシェア ===
    // https://www.linkshare.ne.jp/ で取得
    // 形式例: "lsid=12345&lsurl=..." または mid=xxxx
    static let linkshareSiteId: String = ""

    // === バリューコマース ===
    // https://www.valuecommerce.co.jp/ で取得
    // 形式例: "pid=xxxx&sid=yyyy"
    static let valuecommercePid: String = ""
    static let valuecommerceSid: String = ""

    // === a8.net ===
    // https://www.a8.net/ で取得
    // 形式例: "a8mat=xxxxxxxxxxxxx+yyyy+zzzzz"
    static let a8AffiliateId: String = ""
}

// MARK: - AffiliateLink

struct AffiliateLink: Identifiable {
    let id = UUID()
    let platform: AffiliatePlatform
    let brandName: String
    let searchQuery: String
    let url: URL
}

enum AffiliatePlatform: String, CaseIterable {
    case rakuten = "楽天市場"
    case amazon  = "Amazon"
    case linkshare = "リンクシェア"
    case valuecommerce = "バリューコマース"
    case a8net = "a8.net"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .rakuten: return "cart.fill"
        case .amazon:  return "shippingbox.fill"
        case .linkshare: return "bag.fill"
        case .valuecommerce: return "figure.child.and.lock.fill"
        case .a8net: return "tag.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .rakuten: return "#BF0000"
        case .amazon:  return "#FF9900"
        case .linkshare: return "#0073E6"
        case .valuecommerce: return "#00B900"
        case .a8net: return "#F15A24"
        }
    }

    /// このASPのアフィリエイトIDが設定済みか
    var isConfigured: Bool {
        switch self {
        case .rakuten:
            return !AffiliateConfig.affiliateIdRakuten.isEmpty
        case .amazon:
            return !AffiliateConfig.associateTagAmazon.isEmpty
        case .linkshare:
            return !AffiliateConfig.linkshareSiteId.isEmpty
        case .valuecommerce:
            return !AffiliateConfig.valuecommercePid.isEmpty && !AffiliateConfig.valuecommerceSid.isEmpty
        case .a8net:
            return !AffiliateConfig.a8AffiliateId.isEmpty
        }
    }
}

// MARK: - AffiliateManager

final class AffiliateManager {
    static let shared = AffiliateManager()
    private init() {}

    // =============================================================================
    // 【関数サマリー】generateLinks
    // 目的: ブランド名と子供服カテゴリから全ASPのアフィリエイトリンクを生成する
    // 引数:
    //   - brandName: String - 検索するブランド名（例: "UNIQLO"）
    //   - category: String? - アイテムカテゴリ（例: "トップス"）。検索キーワードに追加される
    //   - size: Int? - サイズ（例: 90）。検索キーワードに追加される
    //   - preferredOnly: Bool - trueの場合、ブランド別最適ASPのみを返す（デフォルトfalse）
    // 戻り値: [AffiliateLink] - 設定済みASPのリンク配列（URLが生成できない場合は空）
    // =============================================================================
    func generateLinks(brandName: String, category: String? = nil, size: Int? = nil, preferredOnly: Bool = false) -> [AffiliateLink] {
        let trimmed = brandName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        var query = trimmed
        if let category = category, !category.isEmpty {
            query += " \(category)"
        }
        if let size = size {
            query += " \(size)cm"
        }
        query += " ベビー 子供服"

        let platforms = preferredOnly ? Self.preferredPlatforms(for: trimmed) : AffiliatePlatform.allCases
        var links: [AffiliateLink] = []

        for platform in platforms where platform.isConfigured {
            if let url = Self.makeURL(for: platform, query: query) {
                links.append(AffiliateLink(
                    platform: platform,
                    brandName: trimmed,
                    searchQuery: query,
                    url: url
                ))
            }
        }

        return links
    }

    // =============================================================================
    // 【関数サマリー】generateLinksForPost
    // 目的: 投稿のアイテムリストから全アフィリエイトリンクを一括生成する
    // 引数:
    //   - items: [PostItem] - 投稿に紐づくアイテムリスト
    // 戻り値: [(item: PostItem, links: [AffiliateLink])] - アイテムとリンクのペア配列
    // =============================================================================
    func generateLinksForPost(items: [PostItem]) -> [(item: PostItem, links: [AffiliateLink])] {
        items.compactMap { item in
            let links = generateLinks(
                brandName: item.custom_name,
                category: item.category,
                size: item.size_value
            )
            guard !links.isEmpty else { return nil }
            return (item: item, links: links)
        }
    }

    // MARK: - ブランド別最適ASPマッピング
    // =============================================================================
    // ブランド名（小文字化・正規化）→ おすすめASP配列
    // 登録済みのASPのみがリンク生成対象になる
    // 追加例:
    //   "petitmain": [.valuecommerce, .rakuten, .a8net],
    // =============================================================================
    private static let brandPreferredMap: [String: [AffiliatePlatform]] = [
        // ファストファッション → Amazon（在庫・配送が速い）・楽天
        "uniqlo": [.amazon, .rakuten],
        "gu": [.amazon, .rakuten],
        "zara": [.amazon, .rakuten],
        "h&m": [.amazon, .rakuten],
        "petitmain": [.amazon, .rakuten, .valuecommerce],

        // 人気子供服ブランド → 楽天（ポイント還元・セール）・リンクシェア
        "ミキハウス": [.rakuten, .linkshare, .a8net],
        "mikihouse": [.rakuten, .linkshare, .a8net],
        "ファミリア": [.rakuten, .linkshare],
        "familiar": [.rakuten, .linkshare],
        "メゾピアノ": [.rakuten, .linkshare],
        "mezzopiano": [.rakuten, .linkshare],
        "kp": [.rakuten, .linkshare],
        "ケーピー": [.rakuten, .linkshare],
        "ラルフローレン": [.rakuten, .linkshare, .a8net],
        "ralphlauren": [.rakuten, .linkshare, .a8net],
        "ポロラルフローレン": [.rakuten, .linkshare, .a8net],

        // カジュアル・インポート → バリューコマース（通販・ファミリー）・a8
        "グローバルワーク": [.valuecommerce, .rakuten, .a8net],
        "globalwork": [.valuecommerce, .rakuten, .a8net],
        "アプレレクール": [.valuecommerce, .rakuten, .a8net],
        "apreslescours": [.valuecommerce, .rakuten, .a8net],

        // ベビー・マタニティ専門 → バリューコマース・a8
        "combi": [.valuecommerce, .rakuten, .a8net],
        "コンビ": [.valuecommerce, .rakuten, .a8net],
        "pigeon": [.valuecommerce, .rakuten, .a8net],
        "ピジョン": [.valuecommerce, .rakuten, .a8net],
        "西松屋": [.valuecommerce, .rakuten],
        "nishimatsuya": [.valuecommerce, .rakuten],
        "赤ちゃん本舗": [.valuecommerce, .rakuten],
        "akachanhonpo": [.valuecommerce, .rakuten],

        // スポーツ・アウトドア → リンクシェア・Amazon
        "mizuno": [.linkshare, .amazon, .rakuten],
        "ミズノ": [.linkshare, .amazon, .rakuten],
        "adidas": [.amazon, .linkshare, .rakuten],
        "アディダス": [.amazon, .linkshare, .rakuten],
        "nike": [.amazon, .linkshare, .rakuten],
        "ナイキ": [.amazon, .linkshare, .rakuten],
        "newbalance": [.amazon, .linkshare, .rakuten],
        "ニューバランス": [.amazon, .linkshare, .rakuten],
    ]

    /// ブランド名に対するおすすめASPを取得（未登録ブランドは全ASP）
    private static func preferredPlatforms(for brand: String) -> [AffiliatePlatform] {
        let normalized = brand.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "&", with: "")
        return brandPreferredMap[normalized] ?? AffiliatePlatform.allCases
    }

    // MARK: - Private URL builders

    private static func makeURL(for platform: AffiliatePlatform, query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        switch platform {
        case .rakuten:  return makeRakutenURL(encoded: encoded)
        case .amazon:   return makeAmazonURL(encoded: encoded)
        case .linkshare: return makeLinkshareURL(encoded: encoded)
        case .valuecommerce: return makeValueCommerceURL(encoded: encoded)
        case .a8net:    return makeA8URL(encoded: encoded)
        }
    }

    private static func makeRakutenURL(encoded: String) -> URL? {
        if AffiliateConfig.affiliateIdRakuten.isEmpty {
            return URL(string: "https://search.rakuten.co.jp/search/mall/\(encoded)/")
        } else {
            let target = "https://search.rakuten.co.jp/search/mall/\(encoded)/"
            let targetEnc = target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? target
            return URL(string: "https://hb.afl.rakuten.co.jp/hgc/\(AffiliateConfig.affiliateIdRakuten)/?pc=\(targetEnc)")
        }
    }

    private static func makeAmazonURL(encoded: String) -> URL? {
        if AffiliateConfig.associateTagAmazon.isEmpty {
            return URL(string: "https://www.amazon.co.jp/s?k=\(encoded)")
        } else {
            return URL(string: "https://www.amazon.co.jp/s?k=\(encoded)&tag=\(AffiliateConfig.associateTagAmazon)")
        }
    }

    // リンクシェア: 汎用検索リンク（ブランドページがあれば後で差し替え）
    private static func makeLinkshareURL(encoded: String) -> URL? {
        // リンクシェアは広告主個別のリンクが基本。ここでは Yahoo!ショッピング検索など代替を使用
        // 実際のリンクは広告主毎に linkshare 管理画面で生成したものを使う
        return URL(string: "https://search.shopping.yahoo.co.jp/search?p=\(encoded)")
    }

    // バリューコマース: 汎用検索リンク
    private static func makeValueCommerceURL(encoded: String) -> URL? {
        // pid/sid があれば広告主個別リンク、なければ汎用検索
        if AffiliateConfig.valuecommercePid.isEmpty {
            return URL(string: "https://search.rakuten.co.jp/search/mall/\(encoded)/")
        }
        // 実際のバリューコマースリンクは広告主毎に異なるため、サンプルURL
        return URL(string: "https://ck.jp.ap.valuecommerce.com/servlet/referral?sid=\(AffiliateConfig.valuecommerceSid)&pid=\(AffiliateConfig.valuecommercePid)&vc_url=https://search.rakuten.co.jp/search/mall/\(encoded)/")
    }

    // a8.net: 汎用検索リンク
    private static func makeA8URL(encoded: String) -> URL? {
        if AffiliateConfig.a8AffiliateId.isEmpty {
            return URL(string: "https://search.rakuten.co.jp/search/mall/\(encoded)/")
        }
        // a8 は広告主毎に a8mat が異なるため、汎用的に商品検索を誘導
        return URL(string: "https://a8.net/redirect?a8=\(AffiliateConfig.a8AffiliateId)&q=\(encoded)")
    }
}
