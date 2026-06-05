// =============================================================================
// ファイル名: UIFont+Swizzle.swift
// 役割: UIFontのsystemFont系メソッドをZen Kaku Gothic Newに差し替える
// 仕組み: Method Swizzlingにより、既存コードを変更せずに全体のフォントを変更
// =============================================================================

import UIKit
import ObjectiveC

extension UIFont {

    static func swizzleSystemFont() {
        // フォントが正しく読み込まれているか確認
        let loaded = UIFont(name: "MPLUS1p-Regular", size: 17) != nil
        print("[AppFont] MPLUS1p-Regular loaded: \(loaded)")

        let methods: [(Selector, Selector)] = [
            (
                #selector(UIFont.systemFont(ofSize:)),
                #selector(UIFont.zkgn_systemFont(ofSize:))
            ),
            (
                #selector(UIFont.systemFont(ofSize:weight:)),
                #selector(UIFont.zkgn_systemFont(ofSize:weight:))
            ),
            (
                #selector(UIFont.boldSystemFont(ofSize:)),
                #selector(UIFont.zkgn_boldSystemFont(ofSize:))
            ),
            (
                #selector(UIFont.italicSystemFont(ofSize:)),
                #selector(UIFont.zkgn_italicSystemFont(ofSize:))
            ),
        ]

        for (original, swizzled) in methods {
            guard
                let originalMethod = class_getClassMethod(UIFont.self, original),
                let swizzledMethod  = class_getClassMethod(UIFont.self, swizzled)
            else {
                print("[AppFont] Failed to swizzle: \(original)")
                continue
            }
            method_exchangeImplementations(originalMethod, swizzledMethod)
            print("[AppFont] Swizzled: \(original)")
        }
    }

    @objc class func zkgn_systemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "MPLUS1p-Regular", size: size)
            ?? zkgn_systemFont(ofSize: size)
    }

    @objc class func zkgn_systemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let name: String
        switch weight {
        case .ultraLight, .thin, .light:
            name = "MPLUS1p-Light"
        case .regular:
            name = "MPLUS1p-Regular"
        case .medium, .semibold:
            name = "MPLUS1p-Medium"
        case .bold:
            name = "MPLUS1p-Bold"
        case .heavy, .black:
            name = "MPLUS1p-Black"
        default:
            name = "MPLUS1p-Regular"
        }
        return UIFont(name: name, size: size) ?? zkgn_systemFont(ofSize: size, weight: weight)
    }

    @objc class func zkgn_boldSystemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "MPLUS1p-Bold", size: size)
            ?? zkgn_boldSystemFont(ofSize: size)
    }

    @objc class func zkgn_italicSystemFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "MPLUS1p-Regular", size: size)
            ?? zkgn_italicSystemFont(ofSize: size)
    }
}
