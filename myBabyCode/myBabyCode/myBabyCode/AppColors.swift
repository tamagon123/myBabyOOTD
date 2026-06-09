// =============================================================================
// ファイル名: AppColors.swift
// 役割: アプリ全体で使用するカラーテーマとカスタムカラー初期化を定義
// 説明:
//   SwiftUIのColor型を拡張し、アプリ専用の配色をプロパティとして定義しています。
//   また、HEXカラーコード（例: "#FF0000"）からColorを生成できるイニシャライザも
//   提供しています。デザイン変更時にはこのファイルのRGB値を修正するだけで
//   全体の配色を一元管理できます。
// =============================================================================

import SwiftUI

extension Color {
    // 生成り (écru) ベースカラー
    // アプリの背景色として使用。優しい生成り色で目に優しい印象に。
    static let ecruBackground = Color(red: 0.96, green: 0.93, blue: 0.86)

    // 差し色：原色ベース
    static let accentRed   = Color(red: 0.82, green: 0.13, blue: 0.08)  // 朱色 / メインCTA
    static let accentBlue  = Color(red: 0.15, green: 0.38, blue: 0.78)  // 青 / 情報・リンク
    static let accentGreen = Color(red: 0.12, green: 0.52, blue: 0.22)  // 緑 / アクション・タグ

    // =============================================================================
    // 【関数サマリー】init(hex:)
    // 目的: HEX文字列（16進数カラーコード）からSwiftUIのColorを生成する
    // 引数:
    //   - hex: String - カラーコード文字列。例: "#FF5733" または "FF5733"
    //                    8桁の場合は最後2桁がアルファ（透明度）として解釈される。
    // 戻り値: Color - 生成されたSwiftUIカラー
    // 処理の流れ:
    //   1. #記号を除去
    //   2. 16進数文字列をUInt64に変換
    //   3. 桁数に応じてRGB（6桁）またはRGBA（8桁）を抽出
    //   4. 0〜255の値を0.0〜1.0に正規化してColorを生成
    // 呼び出し元: EditProfileView, ProfileViewなどでアバター背景色の復元時に使用
    // 備考: 無効な文字列の場合、スキャン失敗でrgb=0となり黒色にフォールバックする。
    // =============================================================================
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let len = h.count
        let r, g, b, a: Double
        if len == 8 {
            r = Double((rgb >> 24) & 0xFF) / 255; g = Double((rgb >> 16) & 0xFF) / 255
            b = Double((rgb >> 8) & 0xFF) / 255;  a = Double(rgb & 0xFF) / 255
        } else {
            r = Double((rgb >> 16) & 0xFF) / 255; g = Double((rgb >> 8) & 0xFF) / 255
            b = Double(rgb & 0xFF) / 255;          a = 1.0
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

import SwiftUI

// =============================================================================
// 【ViewModifier】LargeSheetModifier
// 目的: iOS 16以上で.sheetに.presentationDetents([.large])を適用しiPadで全画面表示
//       iOS 16未満では何もしない（後方互換性のため）
// 使用箇所: HomeView, PostCardView, ProfileView の PostDetailView 表示時
// =============================================================================
struct LargeSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.presentationDetents([.large])
        } else {
            content
        }
    }
}
