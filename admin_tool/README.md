# myBabyOOTD Firestore 管理ツール

Streamlit + Firebase Admin SDK で構築した、Firestore データ管理用 GUI ツールです。
ブランド、アフィリエイトリンク、ショッピングポータルをブラウザ上で直感的に追加・編集・削除できます。

## セットアップ

### 1. Python 仮想環境の作成（推奨）

```bash
cd admin_tool
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# venv\Scripts\activate  # Windows
```

### 2. 依存パッケージのインストール

```bash
pip install -r requirements.txt
```

### 3. Firebase サービスアカウントキーのダウンロード

1. [Firebase Console](https://console.firebase.google.com) にアクセス
2. プロジェクト `mybabyootd-932c9` を選択
3. 歯車アイコン → 「プロジェクトの設定」→「サービスアカウント」タブ
4. 「Firebase Admin SDK」→「秘密鍵の生成」ボタンをクリック
5. ダウンロードされた JSON ファイルを `admin_tool/` ディレクトリ内に `serviceAccountKey.json` として配置

### 4. アプリの起動

```bash
make start
# または
./start.sh
```

ブラウザが自動で開き、管理画面が表示されます。

### 5. スマホからアクセス（同じWi-Fi内）

`start.sh` は `--server.address 0.0.0.0` で起動するため、**同じWi-Fi内のスマホ・iPadからもアクセス可能**です。

**手順：**

1. Mac のローカルIPアドレスを確認
   ```bash
   ifconfig | grep "inet " | grep -v 127.0.0.1
   ```
   （例: `192.168.1.5` など）

2. スマホのブラウザで以下のURLを開く
   ```
   http://192.168.1.5:8501
   ```
   ※ `192.168.1.5` は実際のIPアドレスに置き換えてください

#### 外出先からアクセスしたい場合

同じWi-Fi内でなくてもアクセスしたい場合は **ngrok** が便利です：

```bash
# ngrok のインストール（初回のみ）
brew install ngrok

# トンネル開始（Streamlit起動中に別ターミナルで実行）
ngrok http 8501
```

出力された `https://xxxx.ngrok-free.app` をスマホで開くと、どこからでもアクセスできます。

⚠️ **セキュリティ注意**: ngrok で公開する場合、URLが知られれば誰でもアクセス可能になります。管理作業後は必ず Ctrl+C で停止してください。

## 機能

- **ブランド管理**: ブランド名、カテゴリ、画像URL、公式URLなどを管理
- **アフィリエイトリンク管理**: リンクURL、プラットフォーム、手数料率などを管理
- **ショッピングポータル管理**: ポータル名、URL、アイコンなどを管理

## 注意事項

- `serviceAccountKey.json` は**絶対に Git にコミットしない**でください（`.gitignore` に含まれています）
- 本ツールは管理者用です。サービスアカウントキーの取り扱いには十分注意してください
