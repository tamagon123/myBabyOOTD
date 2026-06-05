from datetime import datetime
import streamlit as st
import pandas as pd


def get_collection(db, collection_name):
    """コレクションの全ドキュメントを取得。DataFrame用に整形し、不足列を補完する。"""
    docs = list(db.collection(collection_name).stream())
    data = []
    for doc in docs:
        item = doc.to_dict()
        item['id'] = doc.id
        data.append(item)
    return data


def get_collection_as_df(db, collection_name, columns):
    """全ドキュメントを取得し、指定列のDataFrameを返す（不足列は空で補完）"""
    data = get_collection(db, collection_name)
    if not data:
        return pd.DataFrame(columns=columns)
    df = pd.DataFrame(data)
    for col in columns:
        if col not in df.columns:
            df[col] = None
    return df[columns]


def apply_edits(db, collection_name, original_df, edited_df, key_column='id', exclude_columns=None):
    """
    DataEditorで変更された行を検出し、Firestoreに反映する。
    original_df: 編集前のDataFrame
    edited_df: data_editorから返されたDataFrame
    key_column: ドキュメントIDの列名
    exclude_columns: 更新対象外の列（例: ['id']）
    """
    if exclude_columns is None:
        exclude_columns = ['id']

    changed_rows = 0
    for idx in edited_df.index:
        doc_id = edited_df.loc[idx, key_column]
        orig_row = original_df[original_df[key_column] == doc_id]
        if orig_row.empty:
            continue
        orig_row = orig_row.iloc[0]

        update_data = {}
        for col in edited_df.columns:
            if col in exclude_columns:
                continue
            new_val = edited_df.loc[idx, col]
            old_val = orig_row.get(col)
            if pd.isna(new_val) and pd.isna(old_val):
                continue
            if pd.isna(new_val) and not pd.isna(old_val):
                update_data[col] = None
            elif str(new_val) != str(old_val):
                update_data[col] = new_val

        if update_data:
            update_document(db, collection_name, doc_id, update_data)
            changed_rows += 1

    if changed_rows > 0:
        st.success(f"✅ {changed_rows} 件を更新しました")
        st.rerun()
    else:
        st.info("変更はありませんでした")


def add_document(db, collection_name, data):
    """新規ドキュメントを追加"""
    # 自動的に created_at, updated_at を付与
    data['created_at'] = datetime.now().isoformat()
    data['updated_at'] = datetime.now().isoformat()
    db.collection(collection_name).add(data)
    st.success(f"✅ {collection_name} に追加しました")
    st.rerun()


def update_document(db, collection_name, doc_id, data):
    """既存ドキュメントを更新"""
    data['updated_at'] = datetime.now().isoformat()
    db.collection(collection_name).document(doc_id).update(data)
    st.success(f"✅ ID: {doc_id} を更新しました")
    st.rerun()


def delete_document(db, collection_name, doc_id):
    """ドキュメントを削除"""
    db.collection(collection_name).document(doc_id).delete()
    st.success(f"🗑️ ID: {doc_id} を削除しました")
    st.rerun()
