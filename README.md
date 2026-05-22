# myBabyCode — 乳児服装共有SNSアプリ

## プロジェクト構成

```
myBabyCode/
├── myBabyCodeApp.swift          # エントリーポイント
├── Models/
│   └── Models.swift             # データモデル (AppUser, Post, PostItem, Follow, 定数)
├── ViewModels/
│   ├── AuthViewModel.swift      # Apple Sign In / ユーザー管理
│   └── PostsViewModel.swift     # 投稿CRUD / いいね / 通報
├── Services/
│   └── WeatherService.swift     # Open-Meteo API 連携
└── Views/
    ├── MainTabView.swift         # タブ + 広告バナー + ボトムナビ
    ├── Auth/
    │   └── AuthView.swift        # ログイン画面
    ├── Home/
    │   ├── HomeView.swift        # タイムライン (新着/おすすめ/フォロー中)
    │   └── PostCardView.swift    # 投稿カード
    ├── NewPost/
    │   └── NewPostView.swift     # 投稿作成
    ├── Search/
    │   └── SearchView.swift      # 絞り込み検索
    └── Profile/
        ├── ProfileView.swift     # プロフィール
        └── EditProfileView.swift # プロフィール編集
```

## セットアップ手順

### 1. Xcodeプロジェクト作成
- Xcode > File > New > Project > iOS App
- Product Name: `myBabyCode`、Interface: SwiftUI、Language: Swift

### 2. Firebase設定
1. [Firebase Console](https://console.firebase.google.com/) でiOSプロジェクトを作成
2. `GoogleService-Info.plist` をダウンロードしてプロジェクトに追加
3. Xcode > File > Add Package Dependencies:
   - `https://github.com/firebase/firebase-ios-sdk.git` (v10以上)
   - 追加対象: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseFirestoreSwift`, `FirebaseStorage`

### 3. Firebase有効化
Firebase Consoleで以下を有効化:
- **Authentication** > Sign-in method > Apple を有効化
- **Firestore Database** > 本番モードで作成
- **Storage** > バケット作成

### 4. Apple Sign In
- Xcode > Target > Signing & Capabilities > `Sign In with Apple` を追加
- Apple Developer Console でApp IDの `Sign In with Apple` を有効化

### 5. Firestoreセキュリティルール (推奨)
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /posts/{postId} {
      allow read: if request.auth != null && resource.data.is_hidden == false;
      allow create: if request.auth != null;
      allow update: if request.auth != null;
    }
    match /follows/{followId} {
      allow read, write: if request.auth != null;
    }
    match /likes/{likeId} {
      allow read, write: if request.auth != null;
    }
    match /reports/{reportId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 6. Storage CORSルール
`StorageMetadata` で画像はJPEG形式で保存。EXIFは `stripEXIF()` で自動除去。

## 天気API
[Open-Meteo](https://open-meteo.com/) を使用（無料・APIキー不要）。
地域（都道府県）選択時に自動で最高気温・最低気温・天気を取得します。

## 広告バナー
`AdBannerView.swift` (MainTabView.swift内) の `ZStack` 内に
`GADBannerView`（Google AdMob）等を組み込んでください。
現状はプレースホルダー表示です。

## 必要なiOSバージョン
iOS 16.0+
