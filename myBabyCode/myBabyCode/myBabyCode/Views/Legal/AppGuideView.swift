// =============================================================================
// ファイル名: AppGuideView.swift
// 役割: アプリの使い方ガイド画面
// 説明:
//   アプリの目的、投稿方法、個人情報の取り扱いについて説明する画面です。
//   初回登録時に表示するか尋ねることができます。
//   最上部にlogo.pngを配置しています。
// =============================================================================

import SwiftUI

struct AppGuideView: View {
    @Environment(\.dismiss) private var dismiss
    var isFirstLaunch: Bool = false
    var onComplete: (() -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // ロゴ
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .padding(.top, 20)

                // ようこそメッセージ
                VStack(spacing: 8) {
                    Text("ようこそ！")
                        .font(.appFont(.bold, size: 24))
                        .foregroundColor(.primary)
                    Text("赤ちゃんの毎日のファッションを記録・共有するアプリ")
                        .font(.appFont(.regular, size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                // セクション: アプリの目的
                GuideSection(
                    icon: "heart.fill",
                    iconColor: .accentRed,
                    title: "アプリの目的",
                    content: "myBabyOOTDは、お子様の成長に合わせた毎日のファッション（OOTD: Outfit Of The Day）を記録・共有するアプリです。\n\n• 毎日のコーディネートを写真で記録\n• 着ているアイテムのブランド・サイズをタグ付け\n• 他のママ・パパのコーディネートを参考に\n• 成長に合わせた着こなしのアイデアを発見"
                )

                // セクション: 投稿方法
                GuideSection(
                    icon: "camera.fill",
                    iconColor: .accentBlue,
                    title: "投稿方法",
                    content: "1. フロント（正面）とバック（背面）の写真を撮影\n2. アイテム情報（ブランド、カテゴリ、サイズ）を入力\n3. 写真にタグを付けてアイテムの位置を指定\n4. 天気情報が自動で取得されます\n5. 説明文を追加して投稿！\n\n※投稿は下書きとして保存することもできます"
                )

                // セクション: いいね・フォロー
                GuideSection(
                    icon: "hand.thumbsup.fill",
                    iconColor: .accentGreen,
                    title: "いいね・フォロー",
                    content: "• 気に入ったコーディネートにいいねを付けられます\n• 気になるユーザーをフォローして最新投稿をチェック\n• いいねした投稿はマイページからいつでも見返せます"
                )

                // セクション: 個人情報の取り扱い
                GuideSection(
                    icon: "lock.shield.fill",
                    iconColor: .purple,
                    title: "個人情報の取り扱い",
                    content: "• お子様のお名前は任意で設定可能（公開されます）\n• 生年月日から年齢を自動計算して表示\n• 位置情報は地域名のみ表示（都道府県・市区町村）\n• 投稿内容は本人のみ削除可能\n• 他ユーザーの不適切な投稿は通報できます\n\n詳細は「設定」>「プライバシーポリシー」でご確認ください。"
                )

                // セクション: 注意事項
                GuideSection(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .orange,
                    title: "注意事項",
                    content: "• 個人を特定できる情報（住所、電話番号等）の公開はお控えください\n• 他のお子様の写真を投稿する際は保護者の同意を得てください\n• 不適切な内容の投稿は削除・アカウント停止の対象となる場合があります\n• アプリの利用に関する詳細は「利用規約」をご確認ください"
                )

                Spacer(minLength: 40)

                // 閉じる/始めるボタン（sheet表示時のみ）
                if isFirstLaunch {
                    Button {
                        onComplete?()
                        dismiss()
                    } label: {
                        Text("はじめる")
                            .font(.appFont(.medium, size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentRed)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color.ecruBackground.ignoresSafeArea())
        .navigationTitle("アプリの使い方")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Guide Section Component

struct GuideSection: View {
    let icon: String
    let iconColor: Color
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.appFont(.regular, size: 18))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(iconColor)
                    .cornerRadius(8)
                
                Text(title)
                    .font(.appFont(.bold, size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(content)
                .font(.appFont(.regular, size: 14))
                .foregroundColor(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .padding(.horizontal, 16)
    }
}
