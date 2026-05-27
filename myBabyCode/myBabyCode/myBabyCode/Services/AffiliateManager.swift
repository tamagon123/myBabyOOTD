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
    // 楽天アフィリエイトID（未設定時はアフィリエイトなしの通常リンク）
    // 登録後: "your-rakuten-affiliate-id" に差し替えてください
    static let affiliateIdRakuten: String = ""

    // Amazon アソシエイトタグ（未設定時はアフィリエイトなしの通常リンク）
    // 登録後: "your-associate-tag-22" に差し替えてください
    static let associateTagAmazon: String = ""
}

// MARK: - AffiliateLink

struct AffiliateLink: Identifiable {
    let id = UUID()
    let platform: AffiliatePlatform
    let brandName: String
    let searchQuery: String
    let url: URL
}

enum AffiliatePlatform: String {
    case rakuten = "楽天市場"
    case amazon  = "Amazon"

    var iconName: String {
        switch self {
        case .rakuten: return "cart.fill"
        case .amazon:  return "shippingbox.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .rakuten: return "#BF0000"
        case .amazon:  return "#FF9900"
        }
    }
}

// MARK: - AffiliateManager

final class AffiliateManager {
    static let shared = AffiliateManager()
    private init() {}

    // =============================================================================
    // 【関数サマリー】generateLinks
    // 目的: ブランド名と子供服カテゴリから楽天・Amazonのアフィリエイトリンクを生成する
    // 引数:
    //   - brandName: String - 検索するブランド名（例: "UNIQLO"）
    //   - category: String? - アイテムカテゴリ（例: "トップス"）。検索キーワードに追加される
    //   - size: Int? - サイズ（例: 90）。検索キーワードに追加される
    // 戻り値: [AffiliateLink] - 楽天・Amazonのリンク配列（URLが生成できない場合は空）
    // 使い方:
    //   let links = AffiliateManager.shared.generateLinks(brandName: "UNIQLO", category: "トップス", size: 80)
    // =============================================================================
    func generateLinks(brandName: String, category: String? = nil, size: Int? = nil) -> [AffiliateLink] {
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

        var links: [AffiliateLink] = []

        if let rakutenURL = makeRakutenURL(query: query) {
            links.append(AffiliateLink(
                platform: .rakuten,
                brandName: trimmed,
                searchQuery: query,
                url: rakutenURL
            ))
        }

        if let amazonURL = makeAmazonURL(query: query) {
            links.append(AffiliateLink(
                platform: .amazon,
                brandName: trimmed,
                searchQuery: query,
                url: amazonURL
            ))
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

    // MARK: - Private URL builders

    // =============================================================================
    // 【関数サマリー】makeRakutenURL
    // 目的: 楽天市場の商品検索URLを生成する（アフィリエイトID付き）
    // 仕様:
    //   アフィリエイトID未設定 → 通常の楽天市場検索URL
    //   アフィリエイトID設定済み → 楽天アフィリエイト経由のURL
    // =============================================================================
    private func makeRakutenURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        if AffiliateConfig.affiliateIdRakuten.isEmpty {
            // アフィリエイトID未設定: 通常検索URL（動作確認用）
            return URL(string: "https://search.rakuten.co.jp/search/mall/\(encoded)/")
        } else {
            // アフィリエイトID設定済み: アフィリエイトリンク
            let targetURL = "https://search.rakuten.co.jp/search/mall/\(encoded)/"
            let targetEncoded = targetURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetURL
            return URL(string: "https://hb.afl.rakuten.co.jp/hgc/\(AffiliateConfig.affiliateIdRakuten)/?pc=\(targetEncoded)")
        }
    }

    // =============================================================================
    // 【関数サマリー】makeAmazonURL
    // 目的: AmazonのアソシエイトリンクURLを生成する
    // 仕様:
    //   アソシエイトタグ未設定 → 通常のAmazon検索URL
    //   アソシエイトタグ設定済み → アソシエイト経由のURL
    // =============================================================================
    private func makeAmazonURL(query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query

        if AffiliateConfig.associateTagAmazon.isEmpty {
            // アソシエイトタグ未設定: 通常検索URL（動作確認用）
            return URL(string: "https://www.amazon.co.jp/s?k=\(encoded)")
        } else {
            // アソシエイトタグ設定済み: アソシエイトリンク
            return URL(string: "https://www.amazon.co.jp/s?k=\(encoded)&tag=\(AffiliateConfig.associateTagAmazon)")
        }
    }
}
