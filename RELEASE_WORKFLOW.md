# リリース・開発運用手順書

## ブランチ構成

| ブランチ | 用途 |
|---|---|
| `main` | 初回リリースまでの開発履歴。以降は審査提出前の統合ブランチとして使用 |
| `release` | 審査通過済みビルドのみを置く本番ブランチ。タグで各バージョンを管理 |
| `develop` | 日常の開発はここで行う |

---

## 日常開発のフロー

```bash
# developブランチで作業
git checkout develop

# 変更をコミット
git add .
git commit -m "feat: xxx機能追加"

# GitHubにpush
git push origin develop
```

---

## バージョンアップ審査に出す手順

### ① developをmainにマージ

```bash
git checkout main
git merge develop --no-ff -m "release: v1.x.0 準備"
git push origin main
```

### ② Xcodeでビルドを上げる

1. Xcode → プロジェクト設定 → `Version` を更新（例: 1.1.0）
2. `Build Number` を更新（例: 2）
3. **Product → Archive** でアーカイブ作成
4. **Distribute App → App Store Connect** でアップロード
5. App Store Connectで審査提出

---

## 審査が通過した後の手順

### ① releaseブランチにマージ＆タグ付け

```bash
git checkout release
git merge main --no-ff -m "release: v1.x.0"
git tag v1.x.0
git push origin release --tags
```

### ② developを最新に同期

```bash
git checkout develop
git merge release
git push origin develop
```

---

## バージョン履歴

| バージョン | タグ | 内容 | 日付 |
|---|---|---|---|
| 1.0.0 | v1.0.0 | 初回リリース | 審査通過後に記入 |

---

## AdMob 本番確認チェックリスト（リリース前）

- [ ] `AdBannerView.swift` の `bannerAdUnitId` が本番ID（`ca-app-pub-1810074247562384/5573930888`）になっているか
- [ ] `Info.plist` の `GADApplicationIdentifier` が本番ID（`ca-app-pub-1810074247562384~7190264881`）になっているか

## App Store Connect チェックリスト（審査提出前）

- [ ] バージョン番号・ビルド番号を更新したか
- [ ] スクリーンショットをアップロードしたか（6.5インチ or 6.7インチ必須）
- [ ] プライバシーポリシーURLが有効か
- [ ] App内購入（プレミアムプラン）をバージョンに紐付けたか
- [ ] テストアカウント（ユーザー名・パスワード）を入力したか
- [ ] アプリのプライバシー設定が完了しているか

## 注意事項

- `GoogleService-Info.plist` は `.gitignore` で除外済み。**絶対にcommitしないこと**
- `release` ブランチへの直接pushは禁止。必ず `main` 経由でマージすること
- タグは `v{major}.{minor}.{patch}` 形式で統一すること（例: `v1.0.0`, `v1.1.0`）
