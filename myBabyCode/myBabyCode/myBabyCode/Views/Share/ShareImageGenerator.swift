//
//  ShareImageGenerator.swift
//  myBabyCode
//
//  Created by s-tamaki on 2025/01/01.
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ShareImageGenerator {
    
    /// 必要なデータをすべて非同期で集め、最終的なUIImageを出力する
    func createInstagramStoryImage(post: Post) async -> UIImage? {
        do {
            // 1. データの非同期並列取得 (Firestore等のモック処理)
            // ※ ネットワークからの画像ダウンロードもここですべて済ませて、UIImage化しておく
            async let mainImageFetched = fetchMainImage(for: post)
            async let brandsFetched = fetchBrandNames(for: post)
            async let weatherIconFetched = fetchWeatherIcon(for: post.weather_type)
            
            // すべてのダウンロードが完了するのを待つ
            guard let mainImage = await mainImageFetched else { return nil }
            let brands = await brandsFetched
            let weatherIcon = await weatherIconFetched
            
            // 2. SwiftUI View の組み立て
            let template = ShareStoryTemplate(
                mainImage: mainImage,
                userName: post.posterDisplayName ?? "ユーザー",
                ageText: post.posterChildAgeName ?? "赤ちゃん",
                dateText: formatDate(post.created_at.dateValue()),
                brandNames: brands,
                temperature: "\(Int(post.temp_max))°C",
                weatherIcon: weatherIcon
            )
            
            // 3. ImageRenderer による高画質レンダリング
            let renderer = ImageRenderer(content: template)
            renderer.scale = 2.0 // Retina対応（1080x1920が美しく出力されます）
            
            guard let uiImage = renderer.uiImage else {
                print("Failed to render image via ImageRenderer")
                return nil
            }
            
            return uiImage
            
        } catch {
            print("Error generating share image: \(error)")
            return nil
        }
    }
    
    // --- 補助関数 (非同期データ取得) ---
    private func fetchMainImage(for post: Post) async -> UIImage? {
        guard let urlString = post.image_url_front,
              let url = URL(string: urlString) else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            print("Failed to fetch main image: \(error)")
            return nil
        }
    }
    
    private func fetchBrandNames(for post: Post) async -> [String] {
        let postId = post.id ?? post.post_id
        guard !postId.isEmpty else { return [] }
        
        do {
            let db = Firestore.firestore()
            let snap = try await db.collection("posts").document(postId).collection("items")
                .order(by: "item_id")
                .getDocuments()
            
            let items = snap.documents.compactMap { doc -> PostItem? in
                try? doc.data(as: PostItem.self)
            }
            
            // ブランド名をフィルタリングして整形
            return items.compactMap { item in
                if item.brand_id.lowercased() == "custom" {
                    // brand_idがcustomの場合はcustom_nameのみ表示
                    return item.custom_name.isEmpty ? nil : item.custom_name
                } else {
                    // 通常の場合はbrand_id + custom_name
                    let brandName = item.brand_id.isEmpty ? nil : item.brand_id
                    let itemName = (item.custom_name.isEmpty || item.custom_name.lowercased() == "custom") ? nil : item.custom_name
                    
                    if let brand = brandName, let name = itemName {
                        return "\(brand) \(name)"
                    } else if let brand = brandName {
                        return brand
                    } else {
                        return nil
                    }
                }
            }
        } catch {
            print("Failed to fetch brand names: \(error)")
            return []
        }
    }
    
    private func fetchWeatherIcon(for weatherType: String) async -> UIImage? {
        let iconName: String
        switch weatherType.lowercased() {
        case "sunny", "晴れ":
            iconName = "weather_sunny"
        case "cloudy", "曇り":
            iconName = "weather_cloudy"
        case "rainy", "雨":
            iconName = "weather_rainy"
        case "snowy", "雪":
            iconName = "weather_snowy"
        default:
            iconName = "weather_default"
        }
        
        return UIImage(named: iconName)
    }
    
    // 時刻フォーマット
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
