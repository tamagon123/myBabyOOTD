import streamlit as st
import pandas as pd
import sys
import os

sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from src.firebase_client import init_firebase
from src.crud import get_collection_as_df, add_document, delete_document, apply_edits

db = init_firebase()

st.title("🛒 ショッピングポータル管理")

PORTAL_COLUMNS = ['id', 'title', 'description', 'url', 'platform', 'category', 'badge', 'order', 'isActive', 'iconName', 'themeColor']

SF_SYMBOLS = [
    'bag.fill', 'cart.fill', 'shippingbox.fill',
    'tshirt.fill', 'shoe.fill', 'teddybear.fill',
    'stroller.fill', 'heart.fill', 'star.fill',
    'house.fill', 'storefront.fill', 'gift.fill',
    'globe', 'tag.fill', 'ticket.fill',
    'creditcard.fill', 'dollarsign.circle.fill', 'creditcard',
    'person.fill', 'figure.child', 'figure.walk',
    'sun.max.fill', 'cloud.fill', 'moon.fill',
    'car.fill', 'bus.fill', 'airplane',
    'phone.fill', 'envelope.fill', 'bell.fill',
    'camera.fill', 'photo.fill', 'paintbrush.fill',
    'book.fill', 'graduationcap.fill', 'pencil',
    'music.note', 'film.fill', 'gamecontroller.fill',
    'leaf.fill', 'flame.fill', 'drop.fill',
    'pill.fill', 'cross.fill', 'bandage.fill',
    'briefcase.fill', 'folder.fill', 'doc.fill',
    'calendar', 'clock.fill', 'alarm.fill',
    'lock.fill', 'key.fill', 'magnifyingglass',
    'gearshape.fill', 'slider.horizontal.3', 'square.grid.2x2',
    'list.bullet', 'checkmark.circle.fill', 'xmark.circle.fill',
    'info.circle.fill', 'questionmark.circle.fill', 'exclamationmark.circle.fill',
    'arrow.up.circle.fill', 'arrow.down.circle.fill', 'arrow.2.circlepath',
    'paperplane.fill', 'location.fill', 'map.fill',
    'externaldrive.fill', 'archivebox.fill', 'tray.fill',
    'printer.fill', 'scanner.fill', 'faxmachine',
    'display', 'desktopcomputer', 'laptopcomputer',
    'ipad', 'iphone', 'applewatch',
    'headphones', 'hifispeaker.fill', 'tv.fill',
    'play.circle.fill', 'pause.circle.fill', 'stop.circle.fill',
    'backward.fill', 'forward.fill', 'repeat',
    'shuffle', 'mic.fill', 'video.fill',
    'wifi', 'bolt.fill', 'power',
    'battery.100', 'aqi.high', 'fanblades.fill',
    'heater.vertical', 'humidity.fill', 'thermometer.sun.fill',
    'sparkles', 'wand.and.stars', 'dice.fill',
    'puzzlepiece.fill', 'building.columns.fill', 'flag.fill'
]

# SF Symbols名 → 絵文字マッピング（Webブラウザ表示用）
ICON_EMOJI = {
    'bag.fill': '🛍️', 'cart.fill': '🛒', 'shippingbox.fill': '📦',
    'tshirt.fill': '👕', 'shoe.fill': '👟', 'teddybear.fill': '🧸',
    'stroller.fill': '🍼', 'heart.fill': '❤️', 'star.fill': '⭐',
    'house.fill': '🏠', 'storefront.fill': '🏪', 'gift.fill': '🎁',
    'globe': '🌐', 'tag.fill': '🏷️', 'ticket.fill': '🎫',
    'creditcard.fill': '💳', 'dollarsign.circle.fill': '💰', 'creditcard': '💳',
    'person.fill': '👤', 'figure.child': '👶', 'figure.walk': '🚶',
    'sun.max.fill': '☀️', 'cloud.fill': '☁️', 'moon.fill': '🌙',
    'car.fill': '🚗', 'bus.fill': '🚌', 'airplane': '✈️',
    'phone.fill': '📞', 'envelope.fill': '✉️', 'bell.fill': '🔔',
    'camera.fill': '📷', 'photo.fill': '🖼️', 'paintbrush.fill': '🎨',
    'book.fill': '📚', 'graduationcap.fill': '🎓', 'pencil': '✏️',
    'music.note': '🎵', 'film.fill': '🎬', 'gamecontroller.fill': '🎮',
    'leaf.fill': '🍃', 'flame.fill': '🔥', 'drop.fill': '💧',
    'pill.fill': '💊', 'cross.fill': '✝️', 'bandage.fill': '🩹',
    'briefcase.fill': '💼', 'folder.fill': '📁', 'doc.fill': '📄',
    'calendar': '📅', 'clock.fill': '⏰', 'alarm.fill': '⏰',
    'lock.fill': '🔒', 'key.fill': '🔑', 'magnifyingglass': '🔍',
    'gearshape.fill': '⚙️', 'slider.horizontal.3': '🎚️', 'square.grid.2x2': '⊞',
    'list.bullet': '📋', 'checkmark.circle.fill': '✅', 'xmark.circle.fill': '❌',
    'info.circle.fill': 'ℹ️', 'questionmark.circle.fill': '❓', 'exclamationmark.circle.fill': '⚠️',
    'arrow.up.circle.fill': '⬆️', 'arrow.down.circle.fill': '⬇️', 'arrow.2.circlepath': '🔄',
    'paperplane.fill': '📨', 'location.fill': '📍', 'map.fill': '🗺️',
    'externaldrive.fill': '💾', 'archivebox.fill': '📦', 'tray.fill': '📥',
    'printer.fill': '🖨️', 'scanner.fill': '📠', 'faxmachine': '📠',
    'display': '🖥️', 'desktopcomputer': '🖥️', 'laptopcomputer': '💻',
    'ipad': '📱', 'iphone': '📱', 'applewatch': '⌚',
    'headphones': '🎧', 'hifispeaker.fill': '🔊', 'tv.fill': '📺',
    'play.circle.fill': '▶️', 'pause.circle.fill': '⏸️', 'stop.circle.fill': '⏹️',
    'backward.fill': '⏮️', 'forward.fill': '⏭️', 'repeat': '🔁',
    'shuffle': '🔀', 'mic.fill': '🎤', 'video.fill': '📹',
    'wifi': '📶', 'bolt.fill': '⚡', 'power': '🔌',
    'battery.100': '🔋', 'aqi.high': '😷', 'fanblades.fill': '🌀',
    'heater.vertical': '🔥', 'humidity.fill': '💧', 'thermometer.sun.fill': '🌡️',
    'sparkles': '✨', 'wand.and.stars': '🪄', 'dice.fill': '🎲',
    'puzzlepiece.fill': '🧩', 'building.columns.fill': '🏛️', 'flag.fill': '🚩',
}

# 表示用ラベル: "🛍️ bag.fill"
SF_SYMBOLS_LABELS = {s: f"{ICON_EMOJI.get(s, '❓')} {s}" for s in SF_SYMBOLS}
SF_SYMBOLS_OPTIONS = [''] + list(SF_SYMBOLS_LABELS.values())

# 絵文字付き文字列 → 純粋なSF Symbols名
def strip_emoji(label):
    if not label or not isinstance(label, str):
        return label
    parts = label.split(' ', 1)
    return parts[1] if len(parts) == 2 else label

# SF Symbols名 → 絵文字付きラベル
def add_emoji(name):
    if not name or not isinstance(name, str):
        return name
    return f"{ICON_EMOJI.get(name, '❓')} {name}"

THEME_COLORS = {
    '朱色': '#D12114',
    'ピンク': '#FF6B9D',
    'オレンジ': '#FF9900',
    '黄色': '#FFD60A',
    '緑': '#30D158',
    'ミント': '#63E6BE',
    '水色': '#48D1CC',
    '青': '#0A84FF',
    '紫': '#BF5AF2',
    '茶色': '#8D6E63',
    'グレー': '#8E8E93',
    '黒': '#1C1C1E',
}
PLATFORMS = ['rakuten', 'amazon', 'other']

tab_list_edit, tab_add, tab_delete = st.tabs(["📋 一覧・編集", "➕ 新規追加", "🗑️ 削除"])

original_df = get_collection_as_df(db, 'shopping_portals', PORTAL_COLUMNS)

with tab_list_edit:
    if not original_df.empty:
        st.write(f"**合計 {len(original_df)} 件**")
        st.caption("セルを直接クリックして編集 → 画面下部の「変更を保存」ボタンで反映")

        # 表示用: iconName を絵文字付きに変換
        display_df = original_df.copy()
        if 'iconName' in display_df.columns:
            display_df['iconName'] = display_df['iconName'].apply(add_emoji)

        edited_df = st.data_editor(
            display_df,
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
                "isActive": st.column_config.CheckboxColumn("有効"),
                "iconName": st.column_config.SelectboxColumn(
                    "アイコン",
                    options=SF_SYMBOLS_OPTIONS,
                    help="ドロップダウンからアイコンを選択"
                ),
                "themeColor": st.column_config.SelectboxColumn(
                    "テーマ色",
                    options=[''] + list(THEME_COLORS.values()),
                    help="ドロップダウンから色を選択"
                )
            },
            use_container_width=True,
            hide_index=True,
            key="portal_editor"
        )

        if st.button("💾 変更を保存", type="primary", use_container_width=True):
            # 保存前: iconName から絵文字を除去、空文字は None に正規化
            edited_df_raw = edited_df.copy()
            if 'iconName' in edited_df_raw.columns:
                edited_df_raw['iconName'] = edited_df_raw['iconName'].apply(
                    lambda x: strip_emoji(x) if x and str(x).strip() else None
                )
            if 'themeColor' in edited_df_raw.columns:
                edited_df_raw['themeColor'] = edited_df_raw['themeColor'].apply(
                    lambda x: x if x and str(x).strip() else None
                )
            apply_edits(db, 'shopping_portals', original_df, edited_df_raw, exclude_columns=['id'])
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

        # アイコン・色の選択（自由入力も可能）
        st.subheader("🎨 アイコン・テーマ色")
        col_icon, col_color = st.columns(2)
        with col_icon:
            icon_mode = st.radio("アイコン入力方法", ["セレクト", "自由入力"], horizontal=True)
            if icon_mode == "セレクト":
                icon_label = st.selectbox("アイコンを選択", SF_SYMBOLS_OPTIONS, index=0)
                icon_name = strip_emoji(icon_label)
            else:
                icon_name = st.text_input("アイコン名（SF Symbols）", placeholder="例: tshirt.fill")
        with col_color:
            color_mode = st.radio("色入力方法", ["セレクト", "自由入力", "カラーピッカー"], horizontal=True)
            if color_mode == "セレクト":
                color_label = st.selectbox("テーマ色", list(THEME_COLORS.keys()))
                theme_color = THEME_COLORS[color_label]
            elif color_mode == "自由入力":
                theme_color = st.text_input("HEX色コード", placeholder="#FF9900")
            else:
                theme_color = st.color_picker("カラーピッカー", "#D12114")
                theme_color = theme_color.upper()

        # プレビュー（絵文字を大きく表示）
        if icon_name:
            emoji = ICON_EMOJI.get(icon_name, '❓')
            color_style = f"color: {theme_color};" if theme_color else "color: #666;"
            st.markdown(f"""
            <div style="text-align: center; padding: 16px; background: #f0f2f6; border-radius: 12px; margin-top: 8px;">
                <div style="font-size: 56px; margin-bottom: 8px;">{emoji}</div>
                <div style="font-size: 14px; font-weight: bold; {color_style}">{icon_name}</div>
                {f'<div style="font-size: 12px; color: #888; margin-top: 4px;">{theme_color}</div>' if theme_color else ''}
            </div>
            """, unsafe_allow_html=True)

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
                    'isActive': is_active,
                    'iconName': icon_name if icon_name else None,
                    'themeColor': theme_color if theme_color else None
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
