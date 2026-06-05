import streamlit as st
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from src.firebase_client import init_firebase
from src.crud import get_collection_as_df, add_document, delete_document, apply_edits

db = init_firebase()

st.title("🔗 アフィリエイトリンク管理")

LINK_COLUMNS = ['id', 'brandName', 'platform', 'url', 'isActive']
PLATFORMS = ['rakuten', 'amazon', 'linkshare', 'valuecommerce', 'a8net']

tab_list_edit, tab_add, tab_delete = st.tabs(["📋 一覧・編集", "➕ 新規追加", "🗑️ 削除"])

original_df = get_collection_as_df(db, 'affiliate_links', LINK_COLUMNS)

with tab_list_edit:
    if not original_df.empty:
        st.write(f"**合計 {len(original_df)} 件**")
        st.caption("セルを直接クリックして編集 → 画面下部の「変更を保存」ボタンで反映")

        edited_df = st.data_editor(
            original_df,
            num_rows="fixed",
            column_config={
                "id": st.column_config.TextColumn("ID", disabled=True, width="medium"),
                "brandName": st.column_config.TextColumn("ブランド名", required=True),
                "platform": st.column_config.SelectboxColumn("プラットフォーム", options=PLATFORMS, required=True),
                "url": st.column_config.TextColumn("アフィリエイトURL", required=True),
                "isActive": st.column_config.CheckboxColumn("有効")
            },
            use_container_width=True,
            hide_index=True,
            key="link_editor"
        )

        if st.button("💾 変更を保存", type="primary", use_container_width=True):
            apply_edits(db, 'affiliate_links', original_df, edited_df, exclude_columns=['id'])
    else:
        st.info("アフィリエイトリンクデータがありません。'新規追加' タブから登録してください。")

with tab_add:
    with st.form("add_link_form", clear_on_submit=True):
        st.subheader("新規アフィリエイトリンク登録")

        brand_name = st.text_input("ブランド名 *", placeholder="例: GU")
        platform = st.selectbox("プラットフォーム *", PLATFORMS)
        url = st.text_input("アフィリエイトURL *", placeholder="https://...")
        is_active = st.toggle("有効", value=True)

        submitted = st.form_submit_button("登録する", use_container_width=True, type="primary")

        if submitted:
            if not brand_name or not url:
                st.error("ブランド名とURLは必須です")
            else:
                data = {
                    'brandName': brand_name,
                    'platform': platform,
                    'url': url,
                    'isActive': is_active
                }
                add_document(db, 'affiliate_links', data)

with tab_delete:
    if not original_df.empty:
        st.subheader("削除")
        st.caption("削除対象を選択してください。元に戻せません。")

        options = {f"{row['brandName']} ({row['id']})": row for _, row in original_df.iterrows()}
        selected_label = st.selectbox("リンクを選択", options=list(options.keys()))
        selected_row = options[selected_label]
        doc_id = selected_row['id']

        st.warning(f"**{selected_row['brandName']}** を削除します。")
        if st.button("削除する", type="secondary", use_container_width=True):
            delete_document(db, 'affiliate_links', doc_id)
    else:
        st.info("削除可能なリンクデータがありません。")
