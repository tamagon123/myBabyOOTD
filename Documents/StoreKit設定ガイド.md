# StoreKit 2 設定ガイド

> App Store Connect でのサブスクリプション商品作成から、Xcode でのテストまでの手順

---

## Step 1: App Store Connect でサブスクリプション作成

### 1-1. サブスクリプショングループ作成

1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン
2. **アプリ** → 対象アプリを選択
3. 左メニュー → **収益化** → **サブスクリプション**
4. **サブスクリプショングループを作成** をクリック
5. **参照名**: `Remove Ads`（内部用）
6. **サブスクリプショングループID**: `remove_ads`（任意、英数字とアンダースコア）
7. **保存**

### 1-2. サブスクリプション商品作成

1. 作成したグループ内で **サブスクリプションを作成** をクリック
2. **参照名**: `広告非表示プラン`（内部用）
3. **プロダクトID**: `com.tamagon123.mybabyootd.removeads.monthly`
   - 推奨: Bundle Identifier + 機能名 + 周期
   - 例: `com.tamagon123.mybabyootd.removeads.monthly`
4. **定期購読期間**: **1ヶ月**
5. 価格・地域を設定（例: 日本 ¥490/月）
6. **サブスクリプションの詳細**（表示名・説明文）を各言語で入力
7. **レビュー用スクリーンショット**（設定画面のスクリーンショット）をアップロード
8. **保存**

### 1-3. サンドボックステスター作成（テスト用）

1. App Store Connect トップ → **ユーザーとアクセス**
2. **サンドボックステスター** タブ
3. **+** をクリック
4. 実在しない Apple ID（例: `tester001@example.com`）を入力
5. **国・地域**: 日本
6. **保存**

---

## Step 2: Xcode で Product ID を設定

App Store Connect で作成した Product ID をコードに反映します。

### 2-1. SubscriptionConfig の更新

`@/Users/s.tamaki/Documents/Swift/myBabyCode/myBabyCode/myBabyCode/myBabyCode/Services/SubscriptionManager.swift:23-27`

```swift
private enum SubscriptionConfig {
    static let removeAdsProductId: String = "com.tamagon123.mybabyootd.removeads.monthly"
}
```

### 2-2. StoreKit Configuration File（シミュレータテスト用）

シミュレータで購入フローをテストする場合、StoreKit Configuration File を作成します。

1. Xcode → **File → New → File...**
2. **StoreKit Configuration File** を選択 → **Next**
3. ファイル名: `Products.storekit` → **Create**
4. ファイルを開き、以下を設定:
   - **Default Storefront**: Japan
   - **Add New Subscription Group**:
     - Group ID: `remove_ads`
     - Group Name: `Remove Ads`
     - Add Subscription:
       - Reference Name: `広告非表示プラン`
       - Product ID: `com.tamagon123.mybabyootd.removeads.monthly`（App Store Connect と同じ）
       - Type: Auto-Renewable Subscription
       - Duration: 1 Month
       - Price: JPY 490
       - Subscription Periods: Level 1
5. **Cmd + S** で保存

### 2-3. Scheme に Configuration File を紐付け

1. Xcode → **Product → Scheme → Edit Scheme...**（または `Cmd + <`）
2. 左側 **Run** を選択
3. タブ **Options**
4. **StoreKit Configuration**: `Products.storekit` を選択
5. **Close**

---

## Step 3: テスト購入

### 3-1. シミュレータでのテスト

1. シミュレータ起動
2. アプリを起動 → 設定画面 → 「広告を非表示にする」タップ
3. StoreKit の購入ダイアログが表示される
4. **購入**（サンドボックスでは支払い不要）
5. 購入成功後、`広告非表示中` に変わることを確認

### 3-2. 実機でのテスト

1. iPhone の **設定 → App Store → サンドボックスアカウント** にテスター Apple ID を追加
2. 実機でアプリをビルド・起動
3. 同様に購入フローをテスト

---

## Step 4: 確認項目

| 確認項目 | 期待する動作 |
|----------|-------------|
| 価格表示 | `¥490/月` など App Store Connect で設定した価格が表示される |
| 購入ダイアログ | Apple の標準購入ダイアログが表示される |
| 購入成功後 | 設定画面で「広告非表示中」に変わる |
| 広告非表示 | 購入後、各画面の `AdBannerView` が非表示になる |
| 購入復元 | 「購入を復元する」で以前の購入が復元される |
| アプリ再起動後 | `Transaction.currentEntitlements` で購入状態が復元される |

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `商品情報を取得できませんでした` | Product ID が不一致 | App Store Connect の ID と `SubscriptionConfig` を一致させる |
| `購入に失敗しました` | サンドボックス未設定 | 実機ではテスター Apple ID を設定。シミュレータでは StoreKit Configuration File を確認 |
| 価格が表示されない | `loadProduct()` 失敗 | ネットワーク接続を確認。App Store Connect で商品が「審査準備完了」状態であることを確認 |
| 購入ダイアログが出ない | Scheme に StoreKit Config が未紐付け | `Edit Scheme → Options → StoreKit Configuration` でファイルを選択 |

---

## 次のステップ

- **サーバー側検証**（任意だが推奨）: App Store Connect のサーバー通知（Server-to-Server Notifications）を受け取り、購入状態をサーバー側でも管理
- **1-2. プレミアム解除の本番対応**: Firestore で `users/{uid}.subscription_status` を管理し、機種変更時の整合性を確保
