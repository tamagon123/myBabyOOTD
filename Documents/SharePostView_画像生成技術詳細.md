# SharePostView 画像生成技術詳細

## 概要

SharePostViewでは、Instagramストーリーズ用の高品質な共有画像を生成するために、**UIGraphicsImageRenderer**を使用した手動での画像合成方式を採用しています。

## 使用技術

### 主要技術スタック
- **UIGraphicsImageRenderer** - iOS 10以降のモダンな画像生成API
- **Core Graphics** - 低レベルの描画処理
- **UIKit** - 画像処理とテキスト描画
- **SwiftUI** - UIフレームワーク（プレビュー表示）

### 外部ライブラリ
- **使用なし** - 純粋なApple標準APIのみで実装

## 画像生成の流れ

### 1. 初期設定
```swift
private func generateInstagramStoryImage() -> UIImage {
    // Instagramストーリーズ仕様
    let size = CGSize(width: 1080, height: 1920)
    
    // 高品質フォーマット設定
    let format = UIGraphicsImageRendererFormat()
    format.scale = 2.0 // Retina対応
    
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
}
```

### 2. 描画処理
```swift
return renderer.image { context in
    // 全ての描画処理をここで実行
    // 背景、テキスト、画像、図形などを直接描画
}
```

## 具体的な描画要素

### 背景描画
```swift
// 薄い生成り色の背景
UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1.0).setFill()
context.fill(CGRect(origin: .zero, size: size))
```

### テキスト描画
```swift
let textAttr: [NSAttributedString.Key: Any] = [
    .font: UIFont.systemFont(ofSize: 32, weight: .bold),
    .foregroundColor: UIColor.black
]
text.draw(in: rect, withAttributes: textAttr)
```

### 画像描画
```swift
// ネットワークから画像を読み込み
if let imageData = try? Data(contentsOf: URL(string: url)!),
   let uiImage = UIImage(data: imageData) {
    // アスペクト比を維持しながらサイズ計算
    let aspectRatio = originalSize.width / originalSize.height
    let finalHeight = min(photoHeight, maxHeight)
    let finalWidth = finalHeight * aspectRatio
    
    // 角丸処理
    let clippedImage = // 角丸処理
    clippedImage?.draw(in: photoRect)
}
```

### 図形描画
```swift
// 天気バッジの背景
let weatherPath = UIBezierPath(roundedRect: rect, cornerRadius: 8)
weatherBgColor.setFill()
weatherPath.fill()
```

## 描画要素一覧

1. **背景** - 薄い生成り色（RGB: 0.98, 0.97, 0.95）
2. **アプリアイコン** - 最上部中央に配置
3. **ユーザー情報** - 表示名、子供の年齢、地域、日時
4. **メイン写真** - 角丸、アスペクト比維持
5. **天気バッジ** - 背景色＋アイコン＋気温
6. **アイテムタグ** - ドット＋ブランド名
7. **コメント** - 角丸背景

## 技術仕様

### 出力仕様
- **サイズ**: 1080×1920px（Instagramストーリーズ）
- **スケール**: 2.0（Retina品質）
- **フォーマット**: UIImage
- **カラー**: sRGB

### パフォーマンス最適化
```swift
// 非同期処理
DispatchQueue.global(qos: .userInitiated).async {
    // 画像生成処理
    DispatchQueue.main.async {
        // UI更新
    }
}
```

## React Native View Shotとの比較

| 項目 | UIGraphicsImageRenderer | React Native View Shot |
|------|------------------------|----------------------|
| 方式 | 手動での画像合成 | UIコンポーネントのスクリーンショット |
| 制御性 | 完全な制御可能 | 既存UIに依存 |
| 品質 | 高品質（Retina対応） | デバイス依存 |
| 柔軟性 | 高い | 制限あり |
| 実装複雑度 | 高い | 低い |

## データ連携

### Firestoreデータ同期
```swift
// PostItemデータを同期取得
let semaphore = DispatchSemaphore(value: 0)
Task {
    let snap = try await db.collection("posts").document(postId).collection("items").getDocuments()
    localPostItems = snap.documents.compactMap { try? doc.data(as: PostItem.self) }
    semaphore.signal()
}
semaphore.wait()
```

## 特徴と利点

### メリット
- ✅ 完全な制御が可能
- ✅ 高品質な出力（Retina対応）
- ✅ 柔軟なレイアウト設計
- ✅ パフォーマンスが良い
- ✅ Instagram仕様の最適化

### デメリット
- ❌ 実装が複雑
- ❌ 手動での位置計算が必要
- ❌ メンテナンスコストが高い

## まとめ

SharePostViewの画像生成は、**「プログラム的な画像合成」**方式を採用しており、React NativeのView Shotのような既存UIのキャプチャとは異なり、**ゼロから高品質な画像を生成**しています。これにより、Instagramストーリーズ仕様の最適な画像を柔軟に作成可能です。

## 実装ファイル

- **メイン実装**: `/Views/Share/SharePostView.swift`
- **画像生成関数**: `generateInstagramStoryImage()`
- **プレビュー表示**: SwiftUIコンポーネント

## 更新履歴

- 2025/01/01: 初版作成
- 2025/01/01: 天気アイコンを絵文字から画像に変更
- 2025/01/01: 投稿画像のアスペクト比維持機能を追加
- 2025/01/01: ブランド名表示ロジックを修正（customフィルタリング）
