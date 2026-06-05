// =============================================================================
// ファイル名: ShoppingView.swift
// 役割: 買い物タブ画面（各種ショッピングサイトのアフィリエイトリンク一覧）
// 説明:
//   Firestore「shopping_portals」コレクションから動的に取得した
//   ショッピングサイトリンクを表示します。カテゴリ別に整理し、
//   タップで各サイト（アフィリエイトURL）へ遷移します。
// =============================================================================

import SwiftUI

struct ShoppingView: View {
    // === 環境 ===
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var brandService = BrandService.shared

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
                        if brandService.isLoading && brandService.shoppingPortals.isEmpty {
                            ProgressView()
                                .padding(.top, 40)
                        } else if filteredPortals.isEmpty {
                            Text("リンクがありません")
                                .font(.appFont(.regular, size: 14))
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                        } else {
                            ForEach(filteredPortals) { portal in
                                PortalLinkCard(portal: portal)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("買い物")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
    // 【Computed Property】filteredPortals
    // 目的: 選択中カテゴリでフィルタリングされた入口リンク一覧
    // =============================================================================
    private var filteredPortals: [ShoppingPortal] {
        let portals = brandService.shoppingPortals.isEmpty ? fallbackPortals : brandService.shoppingPortals
        if selectedCategory == .all {
            return portals
        }
        return portals.filter { $0.category == selectedCategory.rawValue }
    }

    /// Firestore未接続時のローカルフォールバック
    private var fallbackPortals: [ShoppingPortal] {
        [
            ShoppingPortal(id: "amazon_baby", title: "Amazon ベビーストア", description: "ベビー用品が豊富なAmazonのベビー専門ストア", url: "https://www.amazon.co.jp/baby", platform: "amazon", category: "ベビー用品", badge: "おすすめ", order: 0, isActive: true),
            ShoppingPortal(id: "rakuten_baby", title: "楽天 ベビー・キッズ", description: "ポイント還元率が高い楽天のベビー・キッズ用品", url: "https://www.rakuten.co.jp/baby", platform: "rakuten", category: "ベビー用品", badge: nil, order: 1, isActive: true),
            ShoppingPortal(id: "shimamura", title: "しまむらオンライン", description: "プチプラベビー服のしまむら。オンラインで便利に", url: "https://www.shimamura.gr.jp/", platform: "other", category: "ベビー服", badge: "プチプラ", order: 2, isActive: true),
            ShoppingPortal(id: "nishimatsuya", title: "西松屋オンライン", description: "赤ちゃんのデパート西松屋。定番アイテムが充実", url: "https://www.nishimatsuya.co.jp/", platform: "other", category: "ベビー服", badge: "定番", order: 3, isActive: true),
            ShoppingPortal(id: "hm_kids", title: "H&M キッズ", description: "おしゃれな北欧デザインの子供服", url: "https://www2.hm.com/ja_jp/kids.html", platform: "other", category: "キッズ服", badge: "おしゃれ", order: 4, isActive: true),
            ShoppingPortal(id: "gu_kids", title: "GU キッズ", description: "リーズナブルで着やすい子供服", url: "https://www.gu-global.com/jp/ja/kids", platform: "other", category: "キッズ服", badge: "リーズナブル", order: 5, isActive: true),
            ShoppingPortal(id: "ifme", title: "IFME イフミー", description: "足育を応援する子供靴の専門ブランド", url: "https://www.ifmeshoes.com/", platform: "other", category: "靴", badge: "足育", order: 6, isActive: true),
            ShoppingPortal(id: "mikihouse", title: "MIKI HOUSE", description: "高品質な日本製子供靴", url: "https://www.mikihouse.co.jp/", platform: "other", category: "靴", badge: "日本製", order: 7, isActive: true),
            ShoppingPortal(id: "toysrus", title: "トイザらス", description: "おもちゃが豊富なトイザらスオンライン", url: "https://www.toysrus.co.jp/", platform: "other", category: "おもちゃ", badge: "豊富", order: 8, isActive: true),
            ShoppingPortal(id: "bornerund", title: "ボーネルンド", description: "知育玩具と北欧雑貨のセレクトショップ", url: "https://www.borneLund.com/", platform: "other", category: "おもちゃ", badge: "知育", order: 9, isActive: true),
            ShoppingPortal(id: "akachan", title: "アカチャンホンポ", description: "ベビー用品が充実する総合専門店", url: "https://www.akachan.co.jp/", platform: "other", category: "ベビー用品", badge: "総合", order: 10, isActive: true),
            ShoppingPortal(id: "angeliebe", title: "エンジェリーベ", description: "マタニティウェアとベビー用品の通販", url: "https://www.angeliebe.co.jp/", platform: "other", category: "マタニティ", badge: "マタニティ", order: 11, isActive: true),
            ShoppingPortal(id: "wacoal_mat", title: "ワコールマタニティ", description: "機能性に優れたマタニティインナー", url: "https://www.wacoal.co.jp/maternity/", platform: "other", category: "マタニティ", badge: "機能性", order: 12, isActive: true),
            ShoppingPortal(id: "babiesrus", title: "ベビーザらス", description: "ベビー用品の大型専門店", url: "https://www.babiesrus.co.jp/", platform: "other", category: "ベビー用品", badge: "大型店", order: 13, isActive: true),
            ShoppingPortal(id: "combi", title: "コンビ公式", description: "ベビーカーやチャイルドシートの老舗メーカー", url: "https://www.combi.co.jp/", platform: "other", category: "ベビー用品", badge: "老舗", order: 14, isActive: true),
            ShoppingPortal(id: "aprica", title: "アップリカ", description: "ベビーカーとチャイルドシートの専門メーカー", url: "https://www.aprica.com/", platform: "other", category: "ベビー用品", badge: "専門メーカー", order: 15, isActive: true),
        ]
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

// MARK: - CategoryChip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.appFont(isSelected ? .medium : .regular, size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentRed : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

// MARK: - PortalLinkCard

struct PortalLinkCard: View {
    let portal: ShoppingPortal

    var body: some View {
        Button(action: {
            if let url = URL(string: portal.url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // アイコン
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(portalColor.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: portalIcon)
                        .font(.appFont(.regular, size: 24))
                        .foregroundColor(portalColor)
                }

                // テキスト情報
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(portal.title)
                            .font(.appFont(.medium, size: 15))
                            .foregroundColor(.primary)

                        if let badge = portal.badge {
                            Text(badge)
                                .font(.appFont(.medium, size: 10))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentGreen)
                                .cornerRadius(4)
                        }
                    }

                    Text(portal.description)
                        .font(.appFont(.medium, size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // 矢印
                Image(systemName: "chevron.right")
                    .font(.appFont(.regular, size: 14))
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

    private var portalIcon: String {
        switch portal.platform.lowercased() {
        case "rakuten": return "cart.fill"
        case "amazon": return "shippingbox.fill"
        default: return "bag.fill"
        }
    }

    private var portalColor: Color {
        switch portal.platform.lowercased() {
        case "rakuten": return Color(hex: "#BF0000") ?? .accentRed
        case "amazon": return Color(hex: "#FF9900") ?? .orange
        default: return .accentRed
        }
    }
}

// MARK: - Preview

struct ShoppingView_Previews: PreviewProvider {
    static var previews: some View {
        ShoppingView()
    }
}
