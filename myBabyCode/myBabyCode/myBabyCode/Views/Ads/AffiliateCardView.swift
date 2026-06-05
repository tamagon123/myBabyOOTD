// =============================================================================
// ファイル名: AffiliateCardView.swift
// 役割: タイムライン・投稿詳細に挿入するアフィリエイトリンクカードUI
// 説明:
//   楽天市場・Amazonの商品検索ページへ誘導するカードビューです。
//   2種類の表示形態を持ちます：
//   1. AffiliateLinkRow   - 投稿詳細画面のアイテム下に表示する横長の行UI
//   2. AffiliateTimelineCard - タイムラインに N 件ごとに挿入するカードUI
// =============================================================================

import SwiftUI

// MARK: - AffiliateLinkRow
// 投稿詳細画面のアイテムごとに表示するアフィリエイト誘導ボタン
// タップすると楽天市場・Amazonの選択肢を表示し、選んだ先へ遷移する

struct AffiliateLinkRow: View {
    let item: PostItem
    /// true: ブランド別最適ASPのみ / false: 設定済み全ASP
    var preferredOnly: Bool = true
    @State private var showPlatformPicker = false

    private var affiliateLinks: [AffiliateLink] {
        AffiliateManager.shared.generateLinks(
            brandName: item.custom_name,
            category: item.category,
            size: item.size_value,
            preferredOnly: preferredOnly
        )
    }

    var body: some View {
        if !affiliateLinks.isEmpty {
            Button {
                showPlatformPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.appFont(.medium, size: 12))
                    Text(linkLabel)
                        .font(.appFont(.regular, size: 12))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.appFont(.regular, size: 11))
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "\(item.custom_name) を探す",
                isPresented: $showPlatformPicker,
                titleVisibility: .visible
            ) {
                ForEach(affiliateLinks) { link in
                    Button(link.platform.displayName) {
                        UIApplication.shared.open(link.url)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var linkLabel: String {
        if affiliateLinks.count == 1, let first = affiliateLinks.first {
            return "\(first.platform.displayName)で探す"
        }
        return "おすすめのお店で探す"
    }
}

// MARK: - AffiliateTimelineCard
// タイムラインに N 件ごとに挿入するアフィリエイトカード
// 特定ブランドや季節キーワードを使った汎用的な誘導カード

struct AffiliateTimelineCard: View {
    let keyword: String
    /// true: ブランド別最適ASPのみ / false: 設定済み全ASP
    var preferredOnly: Bool = true
    @State private var showPlatformPicker = false

    private var affiliateLinks: [AffiliateLink] {
        AffiliateManager.shared.generateLinks(brandName: keyword, preferredOnly: preferredOnly)
    }

    var body: some View {
        if !affiliateLinks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.appFont(.medium, size: 11))
                        .foregroundColor(.accentRed)
                    Text("「\(keyword)」を探す")
                        .font(.appFont(.regular, size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                    Text("PR")
                        .font(.appFont(.bold, size: 10))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }

                Button {
                    showPlatformPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.appFont(.medium, size: 13))
                        Text(cardLabel)
                            .font(.appFont(.regular, size: 13))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.appFont(.regular, size: 12))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .confirmationDialog(
                "「\(keyword)」を探す",
                isPresented: $showPlatformPicker,
                titleVisibility: .visible
            ) {
                ForEach(affiliateLinks) { link in
                    Button(link.platform.displayName) {
                        UIApplication.shared.open(link.url)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private var cardLabel: String {
        if affiliateLinks.count == 1, let first = affiliateLinks.first {
            return "\(first.platform.displayName)で探す"
        }
        return "おすすめのお店で探す"
    }
}
