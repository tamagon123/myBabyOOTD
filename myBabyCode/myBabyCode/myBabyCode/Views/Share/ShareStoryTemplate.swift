//
//  ShareStoryTemplate.swift
//  myBabyCode
//
//  Created by s-tamaki on 2025/01/01.
//

import SwiftUI

struct ShareStoryTemplate: View {
    // 描画に必要な素材はすべて事前にロードして渡す
    let mainImage: UIImage
    let userName: String
    let ageText: String
    let dateText: String
    let brandNames: [String]
    let temperature: String
    let weatherIcon: UIImage? // 絵文字ではなく洗練されたアイコン画像

    var body: some View {
        ZStack {
            // 1. 背景：基本の生成り色
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()

            // 2. メイン写真：画面いっぱいに配置（アスペクト比を保ってクリップ）
            Image(uiImage: mainImage)
                .resizable()
                .scaledToFill()
                .frame(width: 1080, height: 1920)
                .clipped()

            // 3. グラデーションオーバーレイ（下部の文字を読みやすくするため、ごく薄く）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    Color.clear,
                    Color.black.opacity(0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            // 4. 情報レイアウト（雑誌のカバーのような配置）
            VStack(alignment: .leading, spacing: 0) {
                
                // 【上部】ヘッダー情報（日付と天気情報）
                HStack(alignment: .lastTextBaseline) {
                    Text(dateText.uppercased())
                        .font(.custom("HelveticaNeue-Medium", size: 28))
                        .tracking(2) // 文字間隔を広げて洗練させる
                    
                    Spacer()
                    
                    if let weather = weatherIcon {
                        Image(uiImage: weather)
                            .renderingMode(.template) // 白色に統一
                            .resizable()
                            .frame(width: 36, height: 36)
                    }
                    Text(temperature)
                        .font(.custom("HelveticaNeue-Light", size: 28))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 60)
                .padding(.top, 80)

                Spacer()

                // 【下部】ユーザー情報 ＆ ブランドタグ
                VStack(alignment: .leading, spacing: 24) {
                    
                    // ユーザー・お子様情報
                    VStack(alignment: .leading, spacing: 8) {
                        Text(userName)
                            .font(.custom("HelveticaNeue-Bold", size: 42))
                        Text(ageText)
                            .font(.custom("HelveticaNeue-Regular", size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // ブランド名一覧（シンプルに「/」で区切って並べるカタログ風スタイル）
                    if !brandNames.isEmpty {
                        Text(brandNames.joined(separator: "   /   "))
                            .font(.custom("AvenirNext-Medium", size: 22))
                            .tracking(1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(BlurView(style: .systemUltraThinMaterialDark)) // 背景をほんのりボカす
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 60)
                
                // 【最下部】アプリのウォーターマーク（ロゴを広告ではなくデザインの一部にする）
                HStack {
                    Spacer()
                    Text("G E N E R A T E D  B Y  M Y B A B Y O O T D")
                        .font(.custom("HelveticaNeue-Light", size: 16))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.bottom, 50)
            }
        }
        .frame(width: 1080, height: 1920) // Instagram Stories規格に固定
    }
}

// すりガラス効果を出すためのヘルパー
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    // プレビュー用のダミーデータ
    ShareStoryTemplate(
        mainImage: UIImage(systemName: "photo") ?? UIImage(),
        userName: "YUKI",
        ageText: "1y 2m",
        dateText: "2026.07.01",
        brandNames: ["Comme des Garçons", "Scye", "Steven Alan"],
        temperature: "26°C",
        weatherIcon: UIImage(systemName: "sun.max.fill")
    )
}
