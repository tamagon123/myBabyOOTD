// =============================================================================
// ファイル名: ImageCacheService.swift
// 役割: 画像のメモリ・ディスクキャッシュ管理と、キャッシュ付き非同期画像表示Viewを提供
// 説明:
//   アプリ内で多用されるFirebase Storageの画像URLを、毎回ネットワークから
//   ダウンロードするのではなくメモリ＋ディスクにキャッシュすることで、スクロールの
//   カクつきを解消し通信量を節約します。
//   ImageCacheServiceはシングルトン（shared）で、NSCache（メモリ）と
//   FileManager（ディスク）を利用して最大200枚・100MBまで画像を保持します。
//   CachedAsyncImageはSwiftUIのViewで、URLを指定すると自動で
//   キャッシュを確認→未ヒットならダウンロード→表示、という一連の処理を行います。
// =============================================================================

import SwiftUI

// MARK: - ImageCacheService（メモリ＋ディスクキャッシュ管理）

final class ImageCacheService {
    // シングルトンインスタンス。アプリ全体で唯一のキャッシュを共有する。
    static let shared = ImageCacheService()
    // NSCache: iOSが自動でメモリ管理する辞書型キャッシュ。キーはNSString、値はUIImage。
    private let cache = NSCache<NSString, UIImage>()
    // ディスクキャッシュ保存先のディレクトリ
    private let diskCacheDir: URL

    // =============================================================================
    // 【関数サマリー】init
    // 目的: キャッシュの容量制限を設定するプライベートイニシャライザ
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. 保持枚数上限を200枚に設定（古いものから自動削除）
    //   2. 総容量上限を100MBに設定（画像ピクセル数でコスト計算）
    //   3. ディスクキャッシュ用ディレクトリを作成
    // 備考: private initなので外部からはshared経由でしかアクセスできない。
    // =============================================================================
    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024  // 100 MB
        // ディスクキャッシュディレクトリ初期化
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDir = caches.appendingPathComponent("ImageDiskCache", isDirectory: true)
        try? fm.createDirectory(at: diskCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - メモリキャッシュ

    func get(_ url: String) -> UIImage? {
        // 1. メモリキャッシュを先に確認（最も高速）
        if let mem = cache.object(forKey: url as NSString) { return mem }
        // 2. メモリ未ヒット → ディスクキャッシュを確認
        if let disk = loadFromDisk(url: url) {
            // ディスクヒット → メモリにも乗せて次回以降高速化
            setMemory(image: disk, for: url)
            return disk
        }
        return nil
    }

    func set(_ image: UIImage, for url: String) {
        setMemory(image: image, for: url)
        saveToDisk(image: image, url: url)
    }

    private func setMemory(image: UIImage, for url: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        cache.setObject(image, forKey: url as NSString, cost: cost)
    }

    // MARK: - ディスクキャッシュ

    private func diskPath(for url: String) -> URL {
        let fileName = url.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url
        return diskCacheDir.appendingPathComponent(fileName)
    }

    private func loadFromDisk(url: String) -> UIImage? {
        let path = diskPath(for: url)
        guard FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    private func saveToDisk(image: UIImage, url: String) {
        let path = diskPath(for: url)
        // PNGで保存（透過情報も保持）
        if let data = image.pngData() {
            try? data.write(to: path)
        }
    }
}

// MARK: - CachedAsyncImage（キャッシュ付き非同期画像View）
// 説明: URLから画像を非同期で読み込み、キャッシュを活用して表示する汎用View。
//       contentクロージャで表示方法（角丸、リサイズなど）をカスタマイズできる。
//       placeholderクロージャで読み込み中のプレースホルダーを指定できる。

// MARK: - CachedAsyncImageWithSize
// UIImageを直接コンテンツクロージャに渡すバリアント（アスペクト比計算など用途に使用）
struct CachedAsyncImageWithSize<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (UIImage) -> Content
    let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        Group {
            if let img = loadedImage {
                content(img)
            } else {
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    private func load() async {
        guard let urlString = url, !urlString.isEmpty,
              let nsURL = URL(string: urlString) else { return }
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

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?                   // 画像のダウンロードURL（StorageのURLなど）
    let content: (Image) -> Content    // 画像読み込み成功時のView生成クロージャ
    let placeholder: () -> Placeholder // 読み込み中・未設定時のView生成クロージャ

    @State private var loadedImage: UIImage? = nil  // 読み込み完了後の画像を保持
    @State private var isLoading = false            // 多重読み込み防止用フラグ

    // =============================================================================
    // 【関数サマリー】body
    // 目的: SwiftUIのViewプロトコルが要求する本体。読み込み状態に応じて表示を切り替える。
    // 引数: なし
    // 戻り値: some View
    // 処理の流れ:
    //   1. loadedImageが存在 → content(Image)で画像を表示
    //   2. loadedImageがnil  → placeholder()を表示し.taskでload()を非同期実行
    // =============================================================================
    var body: some View {
        Group {
            if let img = loadedImage {
                // キャッシュヒットまたはダウンロード済み → 実画像を表示
                content(Image(uiImage: img))
            } else {
                // 未取得 → プレースホルダーを表示しつつバックグラウンドで読み込み
                placeholder()
                    .task(id: url) { await load() }
            }
        }
    }

    // =============================================================================
    // 【関数サマリー】load
    // 目的: URLから画像を非同期でダウンロードし、キャッシュに保存・表示する
    // 引数: なし
    // 戻り値: なし
    // 処理の流れ:
    //   1. url文字列のバリデーション（nil/空文字/不正URLを除外）
    //   2. ImageCacheService.get()でメモリキャッシュを確認
    //   3. ヒット → loadedImageにセットして即表示
    //   4. 未ヒット → URLSessionでネットワークからダウンロード
    //   5. ダウンロード成功 → ImageCacheService.set()でキャッシュ保存
    //   6. loadedImageにセットして表示反映
    // 呼び出し元: body内の.task修飾子（url変更時に自動再実行）
    // 備考: catchは空（ネットワークエラー時はplaceholderのまま）。
    // =============================================================================
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
