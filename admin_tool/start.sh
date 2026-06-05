#!/bin/bash
# myBabyOOTD 管理ツール 起動スクリプト

# スクリプトのディレクトリに移動
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 仮想環境を有効化
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ 仮想環境 'venv' が見つかりません"
    echo "初回セットアップ: python3 -m venv venv && pip install -r requirements.txt"
    exit 1
fi

# サービスアカウントキーの確認
if [ ! -f "serviceAccountKey.json" ]; then
    echo "⚠️  serviceAccountKey.json が見つかりません"
    # 古い名前のファイルを探してリネーム
    JSON_FILE=$(ls *.json 2>/dev/null | head -1)
    if [ -n "$JSON_FILE" ]; then
        echo "→ ${JSON_FILE} を serviceAccountKey.json にリネームします"
        mv "$JSON_FILE" serviceAccountKey.json
    else
        echo "❌ Firebase 秘密鍵ファイルが見つかりません"
        echo "Firebase Console → プロジェクト設定 → サービスアカウント → 秘密鍵の生成"
        exit 1
    fi
fi

echo "🚀 myBabyOOTD 管理ツールを起動します..."
# 0.0.0.0 で待ち受け → 同じWi-Fi内のスマホからもアクセス可能
streamlit run app.py --server.address 0.0.0.0 --server.port 8501
