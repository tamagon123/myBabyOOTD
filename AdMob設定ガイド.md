# AdMob 設定ガイド（Nanikiru）

> 本ガイドは、乳児服装共有SNSアプリ「Nanikiru」に Google AdMob のバナー広告を導入する手順です。
> 現状は `AdBannerView.swift` にプレースホルダー（グレー帯）が表示されています。

---

## 前提条件

| 項目 | 内容 |
|------|------|
| Xcode | 15.0 以降 |
| iOS Target | 16.0 以降 |
| Swift Package Manager | 対応済み（本プロジェクトで使用） |
| Firebase | 既に導入済み |
| AdMob アカウント | [Google AdMob](https://admob.google.com/) で作成済みであること |

---

## 手順1: AdMob アプリ登録

1. [AdMob 管理画面](https://apps.admob.com/) にアクセス
2. **アプリ** → **アプリを追加** → **iOS を選択**
3. アプリ名に `Nanikiru`（または任意の識別名）を入力
4. **iOS バンドル ID** に Xcode プロジェクトの Bundle Identifier を入力
   - 確認方法: Xcode → プロジェクト選択 → **General** タブ → **Bundle Identifier**
   - 例: `com.yourcompany.nanikiru`
5. **このアプリを追加** をクリック

> 追加後、**アプリID（App ID）** が発行されます。以下の形式です：
> `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
> ※このIDは手順3で使用します。

---

## 手順2: 広告ユニット作成

1. AdMob 管理画面で登録したアプリを選択
2. **広告ユニット** タブ → **広告ユニットを追加** → **バナー**
3. 広告ユニット名を入力（例: `Home Banner`）
4. **詳細設定** はデフォルトのまま（後から変更可能）
5. **保存** をクリック

> **広告ユニットID** が発行されます。以下の形式です：
> `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ`
> ※このIDは手順4で使用します。

---

## 手順3: Info.plist にアプリIDを設定

### 3-1. `Info.plist` を開く

- Xcode で `myBabyCode/Info.plist` を選択
- ない場合は `myBabyCodeApp.swift` と同じ階層に作成

### 3-2. 以下のキーを追加

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
<key>SKAdNetworkItems</key>
<array>
  <dict>
    <key>SKAdNetworkIdentifier</key>
    <string>cstr6suwn9.skadnetwork</string>
  </dict>
</array>
```

> `SKAdNetworkItems` は iOS 14.5 以降の ATT（App Tracking Transparency）対応のため推奨されます。

---

## 手順4: SPM で AdMob SDK を追加

### 4-1. Package 追加

1. Xcode でプロジェクトを選択 → **Package Dependencies** タブ
2. **+** ボタンをクリック
3. 以下のURLを入力：
   ```
   https://github.com/googleads/swift-package-manager-google-mobile-ads
   ```
4. **Dependency Rule**: `Up to Next Major Version` → `11.0.0 < 12.0.0`
5. **Add to Target**: `myBabyCode`（メインターゲット）を選択
6. **Add Package** をクリック

### 4-2. ビルド確認

- `Cmd + B` でビルドエラーが出ないことを確認
- エラーが出る場合は Xcode → **File** → **Packages** → **Reset Package Caches**

---

## 手順5: AdBannerView.swift のコード変更

以下のファイルを開いて変更します：
`myBabyCode/Views/Ads/AdBannerView.swift`

### 5-1. import 追加

ファイル先頭の `import SwiftUI` の下に追加：

```swift
import GoogleMobileAds
```

### 5-2. AdConfig の広告ユニットIDを本番IDに変更

```swift
private enum AdConfig {
    // TODO: 手順2で発行した本番広告ユニットIDに変更
    static let bannerAdUnitId: String = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"

    // テスト用ID（開発中のみ使用。リリース前に必ず本番IDに変更）
    // static let bannerAdUnitId: String = "ca-app-pub-3940256099942544/2934735716"

    static let bannerHeight: CGFloat = 50
}
```

> **重要**: App Store 審査時にテスト広告IDのままだとリジェクトされます。必ず本番IDに変更してください。

### 5-3. adContent を実装に差し替え

`adContent` プロパティ全体を以下に置き換え：

```swift
@ViewBuilder
private var adContent: some View {
    GADBannerViewRepresentable(adUnitId: AdConfig.bannerAdUnitId)
        .frame(maxWidth: .infinity)
        .frame(height: AdConfig.bannerHeight)
}
```

### 5-4. GADBannerViewRepresentable のコメントアウトを解除

ファイル下部の `GADBannerViewRepresentable` のコメントをすべて外します。

変更後の完全な `GADBannerViewRepresentable`：

```swift
struct GADBannerViewRepresentable: UIViewRepresentable {
    let adUnitId: String

    func makeUIView(context: Context) -> BannerView {
        let viewWidth = UIScreen.main.bounds.width
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(
            width: viewWidth
        )
        let banner = BannerView(adSize: adaptiveSize)
        banner.adUnitID = adUnitId
        banner.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
```

> `BannerView` は GoogleMobileAds SDK が提供する UIKit の広告ビューです。

### 5-5. 変更後の AdBannerView.swift 全体（参考）

```swift
import SwiftUI
import GoogleMobileAds

private enum AdConfig {
    static let bannerAdUnitId: String = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ"
    static let bannerHeight: CGFloat = 50
}

struct AdBannerView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        if !subscriptionManager.isAdsRemoved {
            GADBannerViewRepresentable(adUnitId: AdConfig.bannerAdUnitId)
                .frame(maxWidth: .infinity)
                .frame(height: AdConfig.bannerHeight)
        }
    }
}

struct GADBannerViewRepresentable: UIViewRepresentable {
    let adUnitId: String

    func makeUIView(context: Context) -> BannerView {
        let viewWidth = UIScreen.main.bounds.width
        let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: viewWidth)
        let banner = BannerView(adSize: adaptiveSize)
        banner.adUnitID = adUnitId
        banner.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
```

---

## 手順6: App Tracking Transparency（ATT）対応【必須】

iOS 14.5 以降、IDFA（広告識別子）の取得にはユーザー同意が必要です。

### 6-1. Info.plist に NSUserTrackingUsageDescription を追加

```xml
<key>NSUserTrackingUsageDescription</key>
<string>あなたに最適な広告を表示するために、広告識別子の使用を許可してください。</string>
```

### 6-2. ATT 許可要求の実装

`AppDelegate.swift` または `myBabyCodeApp.swift` に追加：

```swift
import AppTrackingTransparency
import GoogleMobileAds

// ...

func requestIDFA() {
    if #available(iOS 14, *) {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
            case .authorized:
                print("ATT: 許可済み")
            case .denied:
                print("ATT: 拒否")
            case .notDetermined:
                print("ATT: 未決定")
            case .restricted:
                print("ATT: 制限")
            @unknown default:
                break
            }
            // AdMob の初期化
            MobileAds.shared.start { _ in }
        }
    } else {
        // iOS 14 未満は自動的に許可相当
        MobileAds.shared.start { _ in }
    }
}
```

### 6-3. 起動時に呼び出し

`myBabyCodeApp.swift` の `.onAppear` または `AppDelegate.application(_:didFinishLaunchingWithOptions:)` から呼び出す。

```swift
@main
struct myBabyCodeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    appDelegate.requestIDFA()
                }
        }
    }
}
```

> ATT ダイアログは初回起動時に1回のみ表示されます。ユーザーが拒否しても、広告は表示されますが、ターゲティング精度が低下します。

---

## 手順7: ビルド・動作確認

### 7-1. ビルド

```
Cmd + B
```

エラーが出る場合：
- `import GoogleMobileAds` で "No such module" → SPM のパッケージ解決を待つ、または Xcode を再起動
- `BannerView` が見つからない → SDK バージョンを確認（v11以降では `BannerView`、旧版では `GADBannerView`）

### 7-2. 実機またはシミュレータで確認

- シミュレータでも広告は表示されます（テスト広告が出ます）
- 本番広告IDを使用する場合は **必ず実機** で確認してください

### 7-3. 確認ポイント

| 確認項目 | 想定動作 |
|----------|----------|
| サブスク未加入 | バナー広告が表示される |
| サブスク加入済み | 広告が非表示（`isAdsRemoved = true`） |
| オフライン時 | 広告読み込み失敗。UIが崩れないことを確認 |
| 画面回転 | アダプティブバナーが幅に応じてリサイズ |

---

## 手順8: 広告非表示（プレミアム）との連携確認

現状の `SubscriptionManager` で `isSubscribed = true` の場合、広告は自動的に非表示になります。

確認コード（`AdBannerView.swift`）：

```swift
var body: some View {
    if !subscriptionManager.isAdsRemoved {
        // 広告表示
    }
}
```

`SubscriptionManager.setSubscribed(true)` を呼んだ時に `isAdsRemoved = true` となるため、追加実装は不要です。

---

## トラブルシューティング

### Q1. 広告が表示されない

| 原因 | 対応 |
|------|------|
| 広告ユニットIDが間違い | AdMob 管理画面で確認。新規作成後数分〜数時間の遅延あり |
| Info.plist の App ID が未設定 | `GADApplicationIdentifier` が正しく設定されているか確認 |
| ATT 未許可 | ユーザーが拒否しても広告は表示されるが、ターゲティング広告が減少 |
| ネットワーク不通 | 広告は初回読み込みに時間がかかることがある |

### Q2. テスト広告と本番広告の切り替え

開発中はテスト広告IDを使用し、リリース直前に本番IDに切り替えます。

```swift
#if DEBUG
static let bannerAdUnitId = "ca-app-pub-3940256099942544/2934735716" // テスト
#else
static let bannerAdUnitId = "ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ" // 本番
#endif
```

### Q3. App Store 審査でリジェクトされた

| リジェクト理由 | 対応 |
|--------------|------|
| テスト広告IDのまま | 本番IDに変更 |
| ATT 対応なし | `NSUserTrackingUsageDescription` を追加 |
| 広告が不適切 | AdMob 管理画面で広告カテゴリを制限（子供向けアプリに配慮） |
| 子供向けアプリでターゲティング広告 | AdMob → **子供向け設定** を有効化、コンテンツレーティング設定 |

### Q4. 子供向けアプリ特有の注意点

本アプリは乳児向けSNSのため、COPPA（米国児童オンラインプライバシー保護法）対応が必要です：

1. AdMob 管理画面 → アプリ設定 → **子供向け** を **はい** に設定
2. 広告リクエスト時に `tagForChildDirectedTreatment` を設定：

```swift
let request = Request()
let extras = GADExtras()
extras.additionalParameters = ["tag_for_child_directed_treatment": "true"]
request.register(extras)
banner.load(request)
```

---

## 参考リンク

| リンク | 内容 |
|--------|------|
| [AdMob iOS クイックスタート](https://developers.google.com/admob/ios/quick-start) | 公式ガイド |
| [AdMob バナー広告](https://developers.google.com/admob/ios/banner) | バナー広告実装詳細 |
| [テスト広告](https://developers.google.com/admob/ios/test-ads) | テスト広告ID一覧 |
| [ATT 対応](https://developers.google.com/admob/ios/ios14) | iOS 14 以降の対応 |
| [SPM 導入](https://developers.google.com/admob/ios/swift-package-manager) | Swift Package Manager 経由の導入 |

---

## 変更サマリー

| ファイル | 変更内容 |
|----------|----------|
| `Info.plist` | `GADApplicationIdentifier` + `NSUserTrackingUsageDescription` + `SKAdNetworkItems` 追加 |
| `Package.swift` / Xcode SPM | `Google-Mobile-Ads-SDK` 追加 |
| `AdBannerView.swift` | `import GoogleMobileAds` + プレースホルダー → 実装に差し替え |
| `AppDelegate.swift` / `myBabyCodeApp.swift` | ATT 許可要求 + AdMob 初期化追加 |
