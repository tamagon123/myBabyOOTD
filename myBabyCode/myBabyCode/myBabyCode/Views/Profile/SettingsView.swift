import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
                        Label("プロフィールを編集", systemImage: "person.crop.circle")
                    }
                } header: {
                    Text("アカウント")
                }

                Section {
                    Button(role: .destructive) {
                        showSignOutAlert = true
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("その他")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("ログアウト", isPresented: $showSignOutAlert) {
                Button("キャンセル", role: .cancel) {}
                Button("ログアウト", role: .destructive) {
                    authViewModel.signOut()
                    dismiss()
                }
            } message: {
                Text("ログアウトしますか？")
            }
        }
    }
}
