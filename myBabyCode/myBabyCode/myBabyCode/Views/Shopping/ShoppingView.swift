// =============================================================================
// ファイル名: ShoppingView.swift
// 役割: 買い物タブ画面（各種ショッピングサイトのアフィリエイトリンク一覧）
// 説明:
//   各種ショッピングサイトのアフィリエイトリンクを表示する画面です。
//   カテゴリ別に整理し、タップで各サイトへ遷移します。
// =============================================================================

import SwiftUI

struct ShoppingView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel

    // === 状態 ===
    @State private var selectedCategory: ShoppingCategory = .all

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: 買い物画面の全体レイアウトを定義
    // =============================================================================
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // カテゴリフィルター
                categoryFilterScroll

                // アフィリエイトリンク一覧
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredLinks) { link in
                            AffiliateLinkCard(link: link)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("買い物")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // =============================================================================
    // 【Viewサマリー】categoryFilterScroll
    // 目的: カテゴリ選択スクロールビュー
    // =============================================================================
    private var categoryFilterScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShoppingCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // =============================================================================
    // 【Computed Property】filteredLinks
    // 目的: 選択中カテゴリでフィルタリングされたリンク一覧
    // =============================================================================
    private var filteredLinks: [ShoppingAffiliateLink] {
        if selectedCategory == .all {
            return sampleAffiliateLinks
        }
        return sampleAffiliateLinks.filter { $0.category == selectedCategory }
    }
}

// MARK: - ShoppingCategory

enum ShoppingCategory: String, CaseIterable, Identifiable {
    case all = "すべて"
    case babyClothes = "ベビー服"
    case kidsClothes = "キッズ服"
    case shoes = "靴"
    case toys = "おもちゃ"
    case babyGoods = "ベビー用品"
    case maternity = "マタニティ"

    var id: String { rawValue }
}

// MARK: - ShoppingAffiliateLink

struct ShoppingAffiliateLink: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let url: String
    let category: ShoppingCategory
    let imageName: String?
    let badge: String?
}

// MARK: - Sample Data

let sampleAffiliateLinks: [ShoppingAffiliateLink] = [
    ShoppingAffiliateLink(
        title: "Amazon ベビーストア",
        description: "ベビー用品が豊富なAmazonのベビー専門ストア",
        url: "https://www.amazon.co.jp/baby",
        category: .babyGoods,
        imageName: nil,
        badge: "おすすめ"
    ),
    ShoppingAffiliateLink(
        title: "楽天 ベビー・キッズ",
        description: "ポイント還元率が高い楽天のベビー・キッズ用品",
        url: "https://www.rakuten.co.jp/baby",
        category: .babyGoods,
        imageName: nil,
        badge: nil
    ),
    ShoppingAffiliateLink(
        title: "しまむらオンライン",
        description: "プチプラベビー服のしまむら。オンラインで便利に",
        url: "https://www.shimamura.gr.jp/",
        category: .babyClothes,
        imageName: nil,
        badge: "プチプラ"
    ),
    ShoppingAffiliateLink(
        title: "西松屋オンライン",
        description: "赤ちゃんのデパート西松屋。定番アイテムが充実",
        url: "https://www.nishimatsuya.co.jp/",
        category: .babyClothes,
        imageName: nil,
        badge: "定番"
    ),
    ShoppingAffiliateLink(
        title: "H&M キッズ",
        description: "おしゃれな北欧デザインの子供服",
        url: "https://www2.hm.com/ja_jp/kids.html",
        category: .kidsClothes,
        imageName: nil,
        badge: "おしゃれ"
    ),
    ShoppingAffiliateLink(
        title: "GU キッズ",
        description: "リーズナブルで着やすい子供服",
        url: "https://www.gu-global.com/jp/ja/kids",
        category: .kidsClothes,
        imageName: nil,
        badge: "リーズナブル"
    ),
    ShoppingAffiliateLink(
        title: "IFME イフミー",
        description: "足育を応援する子供靴の専門ブランド",
        url: "https://www.ifmeshoes.com/",
        category: .shoes,
        imageName: nil,
        badge: "足育"
    ),
    ShoppingAffiliateLink(
        title: "MIKI HOUSE",
        description: "高品質な日本製子供靴",
        url: "https://www.mikihouse.co.jp/",
        category: .shoes,
        imageName: nil,
        badge: "日本製"
    ),
    ShoppingAffiliateLink(
        title: "トイザらス",
        description: "おもちゃが豊富なトイザらスオンライン",
        url: "https://www.toysrus.co.jp/",
        category: .toys,
        imageName: nil,
        badge: "豊富"
    ),
    ShoppingAffiliateLink(
        title: "ボーネルンド",
        description: "知育玩具と北欧雑貨のセレクトショップ",
        url: "https://www.borneLund.com/",
        category: .toys,
        imageName: nil,
        badge: "知育"
    ),
    ShoppingAffiliateLink(
        title: "アカチャンホンポ",
        description: "ベビー用品が充実する総合専門店",
        url: "https://www.akachan.co.jp/",
        category: .babyGoods,
        imageName: nil,
        badge: "総合"
    ),
    ShoppingAffiliateLink(
        title: "エンジェリーベ",
        description: "マタニティウェアとベビー用品の通販",
        url: "https://www.angeliebe.co.jp/",
        category: .maternity,
        imageName: nil,
        badge: "マタニティ"
    ),
    ShoppingAffiliateLink(
        title: "ワコールマタニティ",
        description: "機能性に優れたマタニティインナー",
        url: "https://www.wacoal.co.jp/maternity/",
        category: .maternity,
        imageName: nil,
        badge: "機能性"
    ),
    ShoppingAffiliateLink(
        title: "ベビーザらス",
        description: "ベビー用品の大型専門店",
        url: "https://www.babiesrus.co.jp/",
        category: .babyGoods,
        imageName: nil,
        badge: "大型店"
    ),
    ShoppingAffiliateLink(
        title: "コンビ公式",
        description: "ベビーカーやチャイルドシートの老舗メーカー",
        url: "https://www.combi.co.jp/",
        category: .babyGoods,
        imageName: nil,
        badge: "老舗"
    ),
    ShoppingAffiliateLink(
        title: "アップリカ",
        description: "ベビーカーとチャイルドシートの専門メーカー",
        url: "https://www.aprica.com/",
        category: .babyGoods,
        imageName: nil,
        badge: "専門メーカー"
    )
]

// MARK: - CategoryChip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentRed : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

// MARK: - AffiliateLinkCard

struct AffiliateLinkCard: View {
    let link: ShoppingAffiliateLink

    var body: some View {
        Button(action: {
            if let url = URL(string: link.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // アイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentRed.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: "bag.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentRed)
                }

                // テキスト情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(link.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        if let badge = link.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentGreen)
                                .cornerRadius(4)
                        }
                    }

                    Text(link.description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // 矢印
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct ShoppingView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingView()
    }
}
