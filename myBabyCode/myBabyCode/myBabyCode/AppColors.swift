import SwiftUI

extension Color {
    // 生成り (écru) ベースカラー
    static let ecruBackground = Color(red: 0.96, green: 0.93, blue: 0.86)

    // 差し色：原色ベース
    static let accentRed   = Color(red: 0.82, green: 0.13, blue: 0.08)  // 朱色 / メインCTA
    static let accentBlue  = Color(red: 0.15, green: 0.38, blue: 0.78)  // 青 / 情報・リンク
    static let accentGreen = Color(red: 0.12, green: 0.52, blue: 0.22)  // 緑 / アクション・タグ

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
