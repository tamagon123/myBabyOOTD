import streamlit as st

st.set_page_config(
    page_title="myBabyOOTD 管理ツール",
    page_icon="👶",
    layout="wide",
    initial_sidebar_state="expanded"
)

st.title("👶 myBabyOOTD 管理ツール")
st.markdown("Firestore データをブラウザ上で直感的に管理するツールです。")

st.divider()

st.subheader("📋 管理メニュー")

# 各管理ページへのリンク
st.page_link("pages/01_ブランド管理.py", label="🏷️ ブランド管理", use_container_width=True)
st.page_link("pages/02_アフィリエイトリンク管理.py", label="🔗 アフィリエイトリンク管理", use_container_width=True)
st.page_link("pages/03_ショッピングポータル管理.py", label="🛒 ショッピングポータル管理", use_container_width=True)

st.divider()

st.info("""
💡 **セットアップがまだの場合**:  
1. Firebase Console → プロジェクト設定 → サービスアカウント → 秘密鍵の生成  
2. ダウンロードした JSON を `admin_tool/serviceAccountKey.json` として配置  
3. `streamlit run app.py` で再起動
""")
