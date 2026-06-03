# リリース・開発運用手順書

## ブランチの種類（4つ）

アプリのコードを4つの箱に分けて管理しています。

| ブランチ | 何を置く箱か |
|---|---|
| `main` | 初回リリースまでの履歴（もう触らない） |
| `develop` | **普段の開発。いつもここで作業する** |
| `review` | 審査に出す時だけ使う箱 |
| `release` | 審査が通ったコードだけを置く箱 |

```
開発中 → develop → 審査に出す → review → 審査通過 → release
```

---

## 普段の作業（いつもこれ）

毎日コードを書いて保存する時は、**いつも `develop` ブランチ**で行います。

```bash
# ① 自分が develop ブランチにいることを確認
git branch

# ② 変更を保存（add → commit → push の3回）
git add .
git commit -m "〇〇を修正"
git push origin develop
```

**「今どのブランチにいるか？」を確認するコマンド**
```bash
git branch
```
→ `* develop` と表示されていればOKです。

---

## 審査に出す時

### ① まず develop で全ての変更を commit & push する

```bash
git checkout develop
git add .
git commit -m "審査提出用"
git push origin develop
```

### ② reviewブランチに移動して、developの内容を取り込む

```bash
git checkout review
git merge develop --no-ff -m "review: v1.x.0 審査提出"
git push origin review
```

### ③ Xcodeでアーカイブを作成してアップロード

1. Xcode → プロジェクト設定 → `Version` を更新（例: 1.1.0）
2. `Build Number` を更新（例: 2）
3. **Product → Archive** でアーカイブ作成
4. **Distribute App → App Store Connect** でアップロード
5. App Store Connectで審査提出

---

## 審査が却下された時

### ① developに戻って修正する

```bash
git checkout develop
# コードを修正
git add .
git commit -m "fix: 審査指摘の修正"
git push origin develop
```

### ② 再びreviewに送って再提出

```bash
git checkout review
git merge develop --no-ff -m "review: v1.x.0 修正再提出"
git push origin review
```

→ XcodeでArchiveし直して、App Store Connectに再アップロード

---

## 審査が通過した時

### ① reviewの内容をreleaseに送る

```bash
git checkout release
git merge review --no-ff -m "release: v1.x.0"
git tag v1.x.0
git push origin release --tags
```

### ② releaseの内容をdevelopにも反映する

```bash
git checkout develop
git merge release
git push origin develop
```

---

## よく使うコマンドまとめ

| やりたいこと | コマンド |
|---|---|
| 今どのブランチ？ | `git branch` |
| developに移動 | `git checkout develop` |
| 変更を保存（add・commit・push） | `git add .` → `git commit -m "コメント"` → `git push origin develop` |
| reviewに移動 | `git checkout review` |
| developの内容をreviewに取り込む | `git checkout review` → `git merge develop` → `git push origin review` |
| reviewの内容をreleaseに取り込む | `git checkout release` → `git merge review` → `git push origin release` |

---

## バージョン履歴

| バージョン | タグ | 内容 | 日付 |
|---|---|---|---|
| 1.0.0 | v1.0.0 | 初回リリース | 審査通過後に記入 |

---

## リリース前チェックリスト

### AdMob（広告）
- [ ] `AdBannerView.swift` の `bannerAdUnitId` が本番IDになっている

### App Store Connect
- [ ] バージョン番号・ビルド番号を更新した
- [ ] スクリーンショットをアップロードした
- [ ] プライバシーポリシーURLが有効
- [ ] App内購入をバージョンに紐付けた
- [ ] テストアカウントを入力した

### 注意
- `GoogleService-Info.plist` は `.gitignore` で除外済み。**commitしないこと**
- 普段は必ず `develop` ブランチで作業すること
