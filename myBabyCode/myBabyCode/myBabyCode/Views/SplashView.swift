// =============================================================================
// ファイル名: SplashView.swift
// 役割: アプリ起動時に表示されるスプラッシュ（ローディング）画面
// 説明:
//   Firebaseの初期化や認証状態確認が完了するまでの間、ユーザーに表示される
//   一時的な画面です。アプリのアイコンとアプリ名「Nanikiru」、および
//   ProgressView（読み込みインジケータ）を表示し、フェードイン・アニメーションで
//   視覚的な印象を良くしています。authViewModel.isInitializing == trueの間だけ
//   myBabyCodeApp.swiftから表示されます。
// =============================================================================

import SwiftUI

struct SplashView: View {
    // アニメーション用状態変数
    @State private var scale: CGFloat = 0.8   // ロゴの初期スケール（80%）
    @State private var opacity: Double = 0      // 全体の初期透明度（完全透明）

    // =============================================================================
    // 【Viewサマリー】body
    // 目的: スプラッシュ画面のレイアウトを定義する
    // 構成:
    //   1. 背景: 生成り色（ecruBackground）で全画面塗りつぶし
    //   2. VStackで中央に縦積み:
    //      - アプリアイコン（110x110、角丸、影付き）
    //      - アプリ名「Nanikiru」（朱色、太字）
    //      - ProgressView（読み込みインジケータ）
    //   3. onAppearでスプリングアニメーションでフェードイン
    // =============================================================================
    var body: some View {
        ZStack {
            // アプリの基調となる生成り色の背景
            Color.ecruBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                // アプリロゴ画像
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .scaleEffect(scale)    // アニメーション対象: スケール
                    .opacity(opacity)      // アニメーション対象: 透明度

                // iOS標準のくるくる回る読み込みインジケータ
                ProgressView()
                    .tint(.accentRed)
                    .opacity(opacity)
            }
        }
        // 画面表示直後にスプリングアニメーションを実行（0.7倍→1.0倍、透明→不透明）
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
