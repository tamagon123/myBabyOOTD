import SwiftUI

// MARK: - In-memory image cache

final class ImageCacheService {
    static let shared = ImageCacheService()
    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
    }

    func get(_ url: String) -> UIImage? {
        cache.object(forKey: url as NSString)
    }

    func set(_ image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let img = loadedImage {
                content(Image(uiImage: img))
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let urlString = url, !urlString.isEmpty,
              let nsURL = URL(string: urlString) else { return }

        // キャッシュヒット
        if let cached = ImageCacheService.shared.get(urlString) {
            loadedImage = cached
            return
        }

        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: nsURL)
            if let img = UIImage(data: data) {
                ImageCacheService.shared.set(img, for: urlString)
                loadedImage = img
            }
        } catch {}
    }
}
