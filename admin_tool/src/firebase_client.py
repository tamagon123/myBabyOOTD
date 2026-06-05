import os
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

load_dotenv()


def init_firebase():
    """Firebase Admin SDK を初期化し、Firestore クライアントを返す"""
    if not firebase_admin._apps:
        cred_path = os.path.join(os.path.dirname(__file__), '..', 'serviceAccountKey.json')
        
        if os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        else:
            # 環境変数 GOOGLE_APPLICATION_CREDENTIALS を試行
            if os.getenv('GOOGLE_APPLICATION_CREDENTIALS'):
                firebase_admin.initialize_app()
            else:
                raise FileNotFoundError(
                    "serviceAccountKey.json が見つかりません。\n"
                    "Firebase Console → プロジェクト設定 → サービスアカウント → 秘密鍵の生成\n"
                    "でダウンロードした JSON ファイルを admin_tool/ ディレクトリに配置してください。"
                )
    return firestore.client()
