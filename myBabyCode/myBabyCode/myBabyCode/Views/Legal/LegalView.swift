import SwiftUI

// MARK: - Terms of Service

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("利用規約")
                    .font(.title2).bold()
                    .padding(.bottom, 4)

                legalSection(title: "第1条（適用）") {
                    "本規約は、本アプリ（以下「当サービス」）の利用に関する条件を定めるものです。ユーザーは本規約に同意の上でご利用ください。"
                }
                legalSection(title: "第2条（禁止事項）") {
                    "以下の行為を禁止します。\n・他者を誹謗中傷する投稿\n・著作権・肖像権を侵害するコンテンツの投稿\n・未成年者の個人情報を含む投稿\n・スパム・広告目的の投稿\n・その他法令に違反する行為"
                }
                legalSection(title: "第3条（投稿コンテンツ）") {
                    "ユーザーが投稿したコンテンツの著作権はユーザーに帰属します。ただし、当サービスの運営・改善・宣伝目的での使用について、ユーザーは当サービスに対し無償のライセンスを許諾するものとします。"
                }
                legalSection(title: "第4条（免責事項）") {
                    "当サービスは、ユーザー間のトラブルや投稿内容の正確性について一切の責任を負いません。サービスの停止・変更・終了による損害についても同様です。"
                }
                legalSection(title: "第5条（規約の変更）") {
                    "当サービスは必要に応じて本規約を変更することがあります。変更後も継続して利用することで、変更に同意したものとみなします。"
                }
            }
            .padding(20)
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func legalSection(title: String, body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Text(body())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("プライバシーポリシー")
                    .font(.title2).bold()
                    .padding(.bottom, 4)

                legalSection(title: "収集する情報") {
                    "当サービスでは以下の情報を収集します。\n・メールアドレス（認証目的）\n・ニックネーム・アバター（任意）\n・お子さんの生年月日・性別（任意）\n・投稿コンテンツ（写真・テキスト）\n・地域情報（都道府県）"
                }
                legalSection(title: "情報の利用目的") {
                    "収集した情報は以下の目的で利用します。\n・サービスの提供および改善\n・コンテンツの表示・おすすめ機能\n・不正利用の防止"
                }
                legalSection(title: "第三者への提供") {
                    "法令に基づく場合を除き、ユーザーの同意なく第三者に個人情報を提供しません。Firebase（Google LLC）のサービスを利用してデータを管理しています。"
                }
                legalSection(title: "子供のプライバシー") {
                    "当サービスはお子さんのコーディネートを共有するアプリです。お子さんの顔が特定できる写真の投稿は慎重にご判断ください。お子さんの個人情報の取り扱いには十分ご注意ください。"
                }
                legalSection(title: "情報の削除") {
                    "アカウントの削除またはご要望により、投稿情報・プロフィール情報を削除できます。"
                }
                legalSection(title: "お問い合わせ") {
                    "プライバシーに関するお問い合わせは、アプリ内のお問い合わせ機能よりご連絡ください。"
                }
            }
            .padding(20)
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func legalSection(title: String, body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
            Text(body())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
