// =============================================================================
// ファイル名: CachedAvatarImage.swift
// 役割: URLから取得したアバター画像をNSURLCacheでキャッシュして表示するView
// =============================================================================

import SwiftUI

/// URLキャッシュを活用したアバター画像View。
/// 同一URLの画像はメモリ/ディスクキャッシュから即時表示される。
struct CachedAvatarImage: View {
    let url: String

    @State private var uiImage: UIImage? = nil

    var body: some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.ecruBackground
            }
        }
        .task(id: url) {
            uiImage = await Self.loadImage(urlString: url)
        }
    }

    // MARK: - キャッシュ付き画像取得

    static func loadImage(urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)

        // キャッシュヒット確認
        if let cached = URLCache.shared.cachedResponse(for: request),
           let img = UIImage(data: cached.data) {
            return img
        }

        // ネットワーク取得 → キャッシュ保存
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200..<300).contains(httpResponse.statusCode) {
                let cachedData = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cachedData, for: request)
                return UIImage(data: data)
            }
        } catch {}
        return nil
    }
}
