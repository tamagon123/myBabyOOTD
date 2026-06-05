// =============================================================================
// ファイル名: AppFonts.swift
// 役割: アプリ全体で使用するカスタムフォント（Zen Kaku Gothic New）の定義
// 使い方:
//   Text("hello").font(.appFont(.regular, size: 16))
//   Text("hello").font(.appTitle)
//   Text("hello").font(.appBody)
// =============================================================================

import SwiftUI

extension Font {

    // MARK: - ウェイト別ファクトリ
    static func appFont(_ weight: AppFontWeight, size: CGFloat) -> Font {
        Font.custom(weight.fontName, size: size)
    }

    // MARK: - セマンティックスタイル（サイズ固定）
    static let appLargeTitle  = Font.custom(AppFontWeight.black.fontName,   size: 34)
    static let appTitle       = Font.custom(AppFontWeight.bold.fontName,    size: 22)
    static let appTitle2      = Font.custom(AppFontWeight.bold.fontName,    size: 18)
    static let appHeadline    = Font.custom(AppFontWeight.medium.fontName,  size: 17)
    static let appBody        = Font.custom(AppFontWeight.regular.fontName, size: 15)
    static let appCallout     = Font.custom(AppFontWeight.regular.fontName, size: 14)
    static let appCaption     = Font.custom(AppFontWeight.light.fontName,   size: 12)
    static let appCaption2    = Font.custom(AppFontWeight.light.fontName,   size: 11)

    // MARK: - セマンティックスタイル（Dynamic Type 対応）
    static func appFont(_ weight: AppFontWeight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(weight.fontName, size: size, relativeTo: style)
    }
}

// MARK: - フォントウェイト定義
enum AppFontWeight {
    case light, regular, medium, bold, black

    var fontName: String {
        switch self {
        case .light:   return "MPLUS1p-Light"
        case .regular: return "MPLUS1p-Regular"
        case .medium:  return "MPLUS1p-Medium"
        case .bold:    return "MPLUS1p-Bold"
        case .black:   return "MPLUS1p-Black"
        }
    }
}
