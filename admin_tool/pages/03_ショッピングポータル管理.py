import streamlit as st
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from src.firebase_client import init_firebase
from src.crud import get_collection_as_df, add_document, delete_document, apply_edits

db = init_firebase()

st.title("🛒 ショッピングポータル管理")

PORTAL_COLUMNS = ['id', 'title', 'description', 'url', 'platform', 'category', 'badge', 'order', 'isActive']
PLATFORMS = ['rakuten', 'amazon', 'other']

tab_list_edit, tab_add, tab_delete = st.tabs(["📋 一覧・編集", "➕ 新規追加", "🗑️ 削除"])

original_df = get_collection_as_df(db, 'shopping_portals', PORTAL_COLUMNS)

with tab_list_edit:
    if not original_df.empty:
        st.write(f"**合計 {len(original_df)} 件**")
        st.caption("セルを直接クリックして編集 → 画面下部の「変更を保存」ボタンで反映")

        edited_df = st.data_editor(
            original_df,
            num_rows="fixed",
            column_config={
                "id": st.column_config.TextColumn("ID", disabled=True, width="medium"),
                "title": st.column_config.TextColumn("タイトル", required=True),
                "description": st.column_config.TextColumn("説明"),
                "url": st.column_config.TextColumn("URL", required=True),
                "platform": st.column_config.SelectboxColumn("プラットフォーム", options=PLATFORMS, required=True),
                "category": st.column_config.TextColumn("カテゴリ"),
                "badge": st.column_config.TextColumn("バッジ"),
                "order": st.column_config.NumberColumn("表示順", min_value=0, step=1),
                "isActive": st.column_config.CheckboxColumn("有効")
            },
            use_container_width=True,
            hide_index=True,
            key="portal_editor"
        )

        if st.button("💾 変更を保存", type="primary", use_container_width=True):
            apply_edits(db, 'shopping_portals', original_df, edited_df, exclude_columns=['id'])
    else:
        st.info("ショッピングポータルデータがありません。'新規追加' タブから登録してください。")

with tab_add:
    with st.form("add_portal_form", clear_on_submit=True):
        st.subheader("新規ショッピングポータル登録")

        col1, col2 = st.columns(2)
        with col1:
            title = st.text_input("タイトル *", placeholder="例: 楽天市場")
            url = st.text_input("URL *", placeholder="https://...")
            description = st.text_area("説明")
        with col2:
            platform = st.selectbox("プラットフォーム *", PLATFORMS)
            category = st.text_input("カテゴリ")
            badge = st.text_input("バッジ文言")
            order = st.number_input("表示順", min_value=0, value=0, step=1)
            is_active = st.toggle("有効", value=True)

        submitted = st.form_submit_button("登録する", use_container_width=True, type="primary")

        if submitted:
            if not title or not url:
                st.error("タイトルとURLは必須です")
            else:
                data = {
                    'title': title,
                    'description': description,
                    'url': url,
                    'platform': platform,
                    'category': category,
                    'badge': badge,
                    'order': order,
                    'isActive': is_active
                }
                add_document(db, 'shopping_portals', data)

with tab_delete:
    if not original_df.empty:
        st.subheader("削除")
        st.caption("削除対象を選択してください。元に戻せません。")

        options = {f"{row['title']} ({row['id']})": row for _, row in original_df.iterrows()}
        selected_label = st.selectbox("ポータルを選択", options=list(options.keys()))
        selected_row = options[selected_label]
        doc_id = selected_row['id']

        st.warning(f"**{selected_row['title']}** を削除します。")
        if st.button("削除する", type="secondary", use_container_width=True):
            delete_document(db, 'shopping_portals', doc_id)
    else:
        st.info("削除可能なポータルデータがありません。")
