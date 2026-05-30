# myBabyOOTD UI 改修のための Swift / SwiftUI 段階的学習ガイド

> **対象読者**: C# / C の経験はあるが Swift / SwiftUI は初めて。  
> **目的**: 実際に myBabyOOTD の UI コードを読み、修正し、新機能を実装できるようになる。  
> **方針**: 文法の羅列ではなく「ここをこう書き換えたら画面がこう変わる」という因果関係を重視して解説する。

---

## Chapter 0. Swift の基礎文法（C# / C 脳への橋渡し）

### 0.1 変数と定数（var / let）

C# では `int x = 10;` のように型を先に書きます。  
Swift では**型推論**が強力です。宣言時に型を省略できます。

```swift
// Swift: 型推論で Int と判断される
var age = 10          // 変数（後から変更可能）
let pi = 3.14         // 定数（後から変更不可）※ C# の readonly に近い

// 明示的に型を書くことも可能
var name: String = "たまご"
```

**ここを変えると**:  
`var` → `let` に変えた場合、後から値を代入しようとするとコンパイルエラーになります。画面動作には影響しませんが、意図しない書き換えを防ぎます。

### 0.2 関数の書き方

C#: `int Add(int a, int b) { return a + b; }`  
Swift: `func` を使い、戻り値の型は `->` の後に書きます。

```swift
func add(a: Int, b: Int) -> Int {
    return a + b
}

// 呼び出し方
let result = add(a: 3, b: 5)  // 引数ラベル（a, b）を必ず付ける
```

**Swift 特有の文化**:  
引数に**ラベル**が付くため、呼び出し時に「何を渡しているか」が明確になります。  
ラベルを省略したい場合は `_` を使います：

```swift
func greet(_ name: String) {          // _ でラベル省略
    print("Hello, \(name)")
}
greet("World")                        // greet(name: "World") ではない
```

### 0.3 構造体（struct）とクラス（class）

C# にも struct と class はありますが、SwiftUI では **`struct` が View の主力**です。

```swift
struct Person {
    var name: String
    var age: Int
}

var p1 = Person(name: "Yui", age: 3)
var p2 = p1     // 値コピー（C# の struct と同じ）
p2.age = 5
print(p1.age)   // 3 のまま（p1 は書き換わらない）
```

**重要な違い**:  
Swift の `struct` は**値型**。代入＝コピー。  
SwiftUI の View はすべて struct なので、画面を再描画するたびに新しい struct が作られるイメージです。

### 0.4 クロージャ（C# のラムダ式に相当）

```swift
// C#:  x => x * 2
// Swift:
let double = { (x: Int) -> Int in
    return x * 2
}

// 呼び出し
print(double(4))  // 8

// 省略形（SwiftUI でよく見る）
Button(action: { print(" tapped") }) {
    Text("Tap me")
}
```

**SwiftUI での見かた**:  
`{ ... }` のブロックが UI のイベント処理や View の内容を表しています。`in` 以降が処理内容です。

### 0.5 オプショナル（nil / null の概念）

C# には `null` があります。Swift には **`nil`** があり、**オプショナル型 `?`** で表現します。

```swift
var maybeName: String? = "Yui"
maybeName = nil

// 安全に取り出す（アンラップ）
if let name = maybeName {
    print(name)       // maybeName が nil でなければ実行
} else {
    print("No name")
}
```

**コードで見ると**:  
`UIImage?` の `?` は「画像がセットされていない（nil）可能性がある」ことを意味します。  
`PostCardView.swift` で `frontImage: UIImage?` となっているのは「まだ写真を選んでいない状態」を表現するためです。

---

## Chapter 1. SwiftUI の基本概念

### 1.1 View プロトコルとは

SwiftUI では画面に表示されるもの**すべて**が `View` というプロトコルに準拠した struct です。

```swift
struct HelloView: View {       // View プロトコルを準拠
    var body: some View {      // 必須プロパティ: 画面に何を表示するか
        Text("Hello")
    }
}
```

**C# 的なイメージ**:  
WPF の `UserControl` のようなものですが、はるかに軽量で宣言的です。  
`body` が「この View のレンダリング結果」を返します。

### 1.2 some View（型消去）

```swift
var body: some View
```

`some View` は「具体的な View の型を隠す」構文です。  
`body` が `Text(...)` を返しても、`VStack(...)` を返しても、どちらも `some View` として扱えます。  
C# に直接的な対応はありませんが、「戻り値をインターフェースで隠す」ようなイメージです。

### 1.3 プレビュー（PreviewProvider）

```swift
struct HelloView_Previews: PreviewProvider {
    static var previews: some View {
        HelloView()
    }
}
```

Xcode の右側（Canvas）にこの View の表示結果が出ます。  
**ここを変えると**: このプレビュー用コードを書き換えても、アプリの実際の動作には影響しませんが、UI の見た目を確認する際に便利です。

---

## Chapter 2. レイアウトシステム入門

### 2.1 三大スタック（VStack / HStack / ZStack）

SwiftUI のレイアウトは**スタック**で組み立てます。

#### VStack（Vertical Stack）
縦に並べる。

```swift
VStack(spacing: 8) {           // 8ポイントの隙間を入れて縦に並べる
    Text("上")
    Text("中")
    Text("下")
}
```

**ここを変えると**:  
`spacing: 8` → `spacing: 20` にすると、各行の間隔が広がります。  
`alignment: .leading` を追加すると、すべて左寄せになります。

#### HStack（Horizontal Stack）
横に並べる。

```swift
HStack(spacing: 16) {
    Image(systemName: "heart")
    Text("いいね")
    Spacer()                   // 右端までスペースを広げる
    Text("12")
}
```

**ここを変えると**:  
`Spacer()` を抜くと「いいね」と「12」が左に寄ります。  
`Spacer()` を入れると両端に要素が張り付きます。

#### ZStack（Depth Stack）
重ねて表示する。

```swift
ZStack(alignment: .bottomTrailing) {
    Image("photo")             // 下層: 写真
    Text("©2025")              // 上層: コピーライト表記
        .padding()
        .background(Color.black.opacity(0.5))
        .foregroundColor(.white)
}
```

**実コードでの見かた**:  
`PostCardView.swift` の `photoCarousel` では `ZStack` を使って、写真（`TabView`）の上にアイテムタグ（`GeometryReader` + `itemTagDot`）を重ねています。

### 2.2 余白とサイズ（padding / frame）

```swift
Text("Hello")
    .padding()                  // 四方向にデフォルト余白（16pt）
    .padding(.horizontal, 20)  // 左右だけ20pt
    .frame(maxWidth: .infinity) // 横方向に最大まで広げる
    .background(Color.yellow)
```

**Modifier の順序が重要**:  
`.padding()` → `.background()` の順だと「余白を含めて背景色が塗られる」。  
`.background()` → `.padding()` の順だと「背景色の領域だけ塗られて、その外側に余白ができる」。

**実コードで確認**:  
`HomeView.swift` の `AppHeaderView` では `.padding(.horizontal, 16)` と `.frame(height: 52)` を組み合わせて、ヘッダーの高さと左右余白を決めています。

### 2.3 ScrollView と List

#### ScrollView
中身が画面に収まらないときにスクロール可能にする。

```swift
ScrollView(.vertical, showsIndicators: false) {  // 縦スクロール、インジケータ非表示
    VStack(spacing: 16) {
        ForEach(0..<50) { i in
            Text("Row \(i)")
        }
    }
}
```

#### List
行の区切り線や選択ハイライトが自動でつく、データ表示に特化した View。

```swift
List {
    Text("設定項目1")
    Text("設定項目2")
}
```

**実コードでの使い分け**:  
- `HomeView.swift` → `ScrollView` + `LazyVStack`（無限スクロール・プルリフレッシュを自前で実現）
- `SettingsView.swift` → `List`（設定メニュー、セクション分けが簡単）

---

## Chapter 3. 状態とイベント

### 3.1 @State（画面の「記憶」）

```swift
struct CounterView: View {
    @State private var count = 0   // この画面が持つ「状態」

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("+1") {
                count += 1          // 状態が変わる → body が再実行 → 画面が更新
            }
        }
    }
}
```

**C# との違い**:  
WPF では `INotifyPropertyChanged` を実装して `PropertyChanged` イベントを発行しますが、SwiftUI では `@State` を付けるだけで自動的に変更検知→再描画が行われます。

**ここを変えると**:  
`@State` を外すと `count += 1` しても画面が変わりません。コンパイルエラーにはならない場合もありますが、UI とデータが同期しなくなります。

### 3.2 Button と onTapGesture

#### Button

```swift
Button("タップしてね") {
    // タップされたときの処理
    print("Tapped!")
}
```

**実コード**:  
`PostCardView.swift` のいいねボタン：

```swift
Button(action: onLike) {          // action: にタップ時の処理を渡す
    HStack(spacing: 4) {
        Image(systemName: isLiked ? "heart.fill" : "heart")
        Text("\(post.likes_count)")
    }
}
```

**ここを変えると**:  
`action:` の中身を変えると、ボタンタップ時の動作が変わります。  
`Image(systemName: ...)` を別のアイコン名に変えると、ボタンの見た目が変わります。

#### onTapGesture
Button 以外の View（Text、Image など）でもタップ検知したいときに使います。

```swift
Text("タップできます")
    .onTapGesture {
        print("Text tapped")
    }
```

**実コード**:  
`PostCardView.swift` のカード全体をタップして詳細画面を開く処理：

```swift
.onTapGesture {
    showPostDetail = true
}
```

### 3.3 Toggle（スイッチ）と Picker

#### Toggle

```swift
@State private var isOn = false

Toggle("通知を受け取る", isOn: $isOn)   // $ は双方向バインディング
```

`$isOn` の `$` は「この変数を読み書き両方で繋げる」意味です。  
Toggle を操作すると `isOn` が変わり、`isOn` をコードで変えると Toggle の表示も変わります。

#### Picker

```swift
@State private var selected = 1

Picker("選択", selection: $selected) {
    Text("りんご").tag(1)
    Text("ばなな").tag(2)
}
.pickerStyle(.menu)   // または .segmentedStyle
```

**実コード**:  
`ProfileSetupView.swift` で都道府県選択に使われています。  
`SearchView.swift` では `.pickerStyle(.menu)` でプルダウン式の選択 UI を実現しています。

---

## Chapter 4. テキストと画像

### 4.1 Text（文字列の装飾）

```swift
Text("Hello")
    .font(.system(size: 16, weight: .bold))  // サイズ16、太字
    .foregroundColor(.blue)                    // 文字色
    .lineLimit(2)                              // 最大2行
```

**実コード**:  
`PostCardView.swift` の説明文：

```swift
Text(post.description)
    .font(.system(size: 13))
    .foregroundColor(.secondary)   // グレー系の色
    .lineLimit(3)                  // 3行を超えたら「...」で省略
```

**ここを変えると**:  
`.lineLimit(3)` → `.lineLimit(nil)` にすると全文表示されます。  
`.font(.system(size: 13))` → `.font(.title)` にすると大きな見出し風になります。

### 4.2 TextField（1行入力）と TextEditor（複数行入力）

```swift
@State private var name = ""

TextField("名前を入力", text: $name)     // 1行
    .textFieldStyle(.roundedBorder)

TextEditor(text: $name)                  // 複数行（iOS 16以降はTextFieldでもaxis指定可）
    .frame(height: 100)
```

**実コード**:  
`NewPostView.swift` の服装のポイント入力：

```swift
TextField("例：気温が上がったので半袖デビュー！", text: $description, axis: .vertical)
    .lineLimit(3...5)   // 3〜5行で可変
```

**ここを変えると**:  
プレースホルダー文字列（"例：..."）を変えると、入力欄が空のときの薄いヒント文字が変わります。  
`.lineLimit(3...5)` を `.lineLimit(1)` にすると1行入力に戻ります。

### 4.3 Image（システムアイコンと自作画像）

#### SF Symbols（Apple提供のアイコン）

```swift
Image(systemName: "heart.fill")
    .font(.system(size: 24))
    .foregroundColor(.pink)
```

**ここを変えると**:  
`"heart.fill"` → `"star.fill"` にすると星マークになります。  
foregroundColor を `.pink` → `.yellow` に変えると黄色い星になります。

#### 自作画像 / ネットワーク画像

```swift
Image("avatar_bear")          // Assets.xcassets に登録した画像
    .resizable()              // サイズ変更を許可
    .scaledToFill()           // 枠内を埋める（はみ出しあり）
    .frame(width: 44, height: 44)
    .clipShape(Circle())      // 円形にクリップ
```

**実コード**:  
`PostCardView.swift` の投稿者アバター：

```swift
if avatarId.hasPrefix("https://") {
    AsyncImage(url: URL(string: avatarId)) { img in
        img.resizable().scaledToFill()
    } placeholder: { Color.ecruBackground }
} else if avatarImageNames.contains(avatarId) {
    Image(avatarId).resizable().scaledToFill()
} else {
    Image(systemName: "person.fill")
}
```

**解説**:  
- `AsyncImage` → URL からネットワーク経由で画像を取得して表示
- `Image("...")` → アプリ内の画像素材
- `placeholder:` → 読み込み中やエラー時の代替表示

### 4.4 条件付き表示（if / switch）

```swift
var body: some View {
    VStack {
        if isLoggedIn {
            Text("ようこそ")
        } else {
            Text("ログインしてください")
        }
    }
}
```

**実コード**:  
`AuthView.swift` では `isSignUp` フラグで「ログイン画面 / 新規登録画面」を切り替えています。  
`MainTabView.swift` では `selectedTab` の値で表示するタブ画面を切り替えています。

**ここを変えると**:  
条件を変えることで、ユーザー状態（ログイン済みかどうか）に応じて表示する UI を変えることができます。

---

## Chapter 5. 繰り返し表示（ForEach）

### 5.1 基本構文

```swift
let fruits = ["りんご", "ばなな", "みかん"]

VStack {
    ForEach(fruits, id: \.self) { fruit in
        Text(fruit)
    }
}
```

`id: \.self` は「文字列そのものを一意の識別子にする」という意味です。  
配列の要素が `Identifiable` プロトコルに準拠していれば `id:` を省略できます。

**実コード**:  
`HomeView.swift` のタイムライン表示：

```swift
LazyVStack(spacing: 0) {
    ForEach(postsViewModel.posts) { post in       // Post は Identifiable
        PostCardView(post: post, ...)
    }
}
```

**ここを変えると**:  
`spacing: 0` → `spacing: 16` にするとカード同士の隙間が広がります。  
`PostCardView` の代わりに別の View を置くと、タイムラインの1行の見た目が完全に変わります。

### 5.2 インデックスが必要な場合

```swift
ForEach(items.indices, id: \.self) { index in
    Text("\(index + 1). \(items[index])")
}
```

**実コード**:  
`NewPostView.swift` の `itemsSection`：

```swift
ForEach(items.indices, id: \.self) { idx in
    ItemEntryRow(entry: $items[idx], ...)
}
```

**ここを変えると**:  
`items.indices` の代わりに `items` そのものを回してもいいですが、`idx` が必要な場合（タグ付け時に「何番目のアイテムか」を知るため）は `indices` を使います。

---

## Chapter 6. 画面遷移

### 6.1 NavigationView + NavigationLink（階層的遷移）

```swift
NavigationView {
    List {
        NavigationLink(destination: DetailView()) {
            Text("詳細へ")
        }
    }
    .navigationTitle("一覧")
}
```

**実コード**:  
`SettingsView.swift` の設定メニュー：

```swift
NavigationLink(destination: EditProfileView().environmentObject(authViewModel)) {
    Label("プロフィールを編集", systemImage: "person.crop.circle")
}
```

**ここを変えると**:  
`destination:` の View を別のものに変えると、タップ時に遷移する先の画面が変わります。  
`.navigationTitle("一覧")` を変えると画面上部のタイトルが変わります。

### 6.2 sheet（下からスライドするモーダル）

```swift
@State private var showModal = false

Button("開く") {
    showModal = true
}
.sheet(isPresented: $showModal) {
    ModalView()
}
```

**実コード**:  
`MainTabView.swift` の新規投稿ボタン：

```swift
.sheet(isPresented: $showNewPost) {
    NewPostView()
        .environmentObject(authViewModel)
}
```

**ここを変えると**:  
`NewPostView()` の代わりに別の View を渡すと、新規投稿ボタンを押したときに別の画面が開きます。  
`$showNewPost` を true にするコードを他の場所（例：ホーム画面のFAB風ボタン）に移すと、別のトリガーから同じ画面を開けます。

### 6.3 fullScreenCover（全画面モーダル）

```swift
.fullScreenCover(isPresented: $showSplash) {
    SplashView()
}
```

### 6.4 dismiss（閉じる）

```swift
@Environment(\.dismiss) private var dismiss

Button("閉じる") {
    dismiss()    // sheet や NavigationLink で開いた画面を閉じる
}
```

**実コード**:  
`NewPostView.swift`、`SettingsView.swift`、`EditProfileView.swift` など、ほとんどのサブ画面で使われています。  
「閉じる」や「キャンセル」ボタンの処理に `dismiss()` を呼び出すことで、モーダルが閉じます。

---

## Chapter 7. データの流れと MVVM

### 7.1 ObservableObject と @StateObject

ViewModel（画面のためのデータロジック）をクラスで定義します。

```swift
class CounterViewModel: ObservableObject {
    @Published var count = 0   // これが変わると View が再描画される

    func increment() {
        count += 1
    }
}
```

```swift
struct CounterView: View {
    @StateObject private var viewModel = CounterViewModel()

    var body: some View {
        VStack {
            Text("\(viewModel.count)")
            Button("+1") {
                viewModel.increment()
            }
        }
    }
}
```

**C# との比較**:  
`ObservableObject` + `@Published` は WPF の `ViewModelBase` + `INotifyPropertyChanged` の自動版と考えてください。  
`@StateObject` はこの View が ViewModel の所有者（ライフサイクルを管理する）であることを示します。

### 7.2 @EnvironmentObject（共有データ）

複数の画面で同じデータ（ログイン状態など）を共有したいときに使います。

```swift
// App ルートで一度設定
WindowGroup {
    ContentView()
        .environmentObject(authViewModel)
}

// どの子孫 View からでも取得可能
struct SomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Text(authViewModel.currentUser?.displayName ?? "Guest")
    }
}
```

**実コード**:  
`MainTabView.swift` で `authViewModel`、`postsViewModel`、`draftManager` を environmentObject として渡しています。  
`PostCardView.swift` や `NewPostView.swift` では `@EnvironmentObject` でそれらを受け取っています。

**ここを変えると**:  
`.environmentObject(...)` を忘れると、子 View で `@EnvironmentObject` を参照したときに実行時エラー（クラッシュ）します。必ず親から注入してください。

### 7.3 @Binding（子 View から親の状態を変更）

```swift
struct ToggleRow: View {
    @Binding var isOn: Bool   // 親の @State と双方向で繋ぐ

    var body: some View {
        Toggle("有効", isOn: $isOn)
    }
}

struct ParentView: View {
    @State private var setting = false

    var body: some View {
        ToggleRow(isOn: $setting)   // $ を付けて渡す
    }
}
```

**実コード**:  
`ItemEntryRow`（`NewPostView.swift` 内）では `@Binding var entry: NewItemEntry` としています。  
親の `items` 配列の要素を直接書き換えるため、`$items[idx]` として Binding を渡しています。

---

## Chapter 8. myBabyOOTD の View 構造を読む

### 8.1 ファイル構成の俯瞰

```
Views/
  SplashView.swift         // アプリ起動時のロゴ画面
  MainTabView.swift        // ログイン後のメイン画面（3タブ管理）
  Auth/
    AuthView.swift         // ログイン / 新規登録
  Home/
    HomeView.swift         // タイムライン（全投稿 / フォロー中）
    PostCardView.swift     // 1つの投稿カード
    PostDetailView.swift   // 投稿タップ時の詳細画面
  NewPost/
    NewPostView.swift      // 新規投稿作成（写真・天気・アイテム）
  Profile/
    ProfileSetupView.swift // 初回プロフィール設定
    ProfileView.swift      // マイページ / ユーザーページ
    EditProfileView.swift  // プロフィール編集
    SettingsView.swift     // 設定メニュー
  Search/
    SearchView.swift       // 絞り込み検索
  Legal/
    LegalView.swift        // 利用規約 / プライバシーポリシー
```

### 8.2 コードの読み方のコツ

1. **ファイル先頭のコメント** → このファイルが何をするかの概要が書いてあります。
2. **`body` のサマリーコメント** → 画面の構成要素が箇条書きされています。
3. **`// MARK: -` セクション** → 大きな View や関数がどのパートに属するかが視覚的にわかります。
4. **関数/View のサマリーコメント** → 目的・引数・戻り値・処理の流れが記載されています。

### 8.3 実際に改修してみる演習

#### 演習 1: ボタンの色を変える

`PostCardView.swift` の通報ボタンを黄色に変えてみます。

```swift
// Before
Label("通報", systemImage: "exclamationmark.triangle")
    .foregroundColor(.gray)

// After
Label("通報", systemImage: "exclamationmark.triangle")
    .foregroundColor(.yellow)
```

**結果**: 通報ボタンの文字とアイコンが黄色くなります。

#### 演習 2: ヘッダーの高さを変える

`HomeView.swift` の `AppHeaderView`：

```swift
// Before
.frame(height: 52)

// After
.frame(height: 64)
```

**結果**: 画面上部のヘッダー領域が高くなり、上下の余白が増えます。

#### 演習 3: 新しい Text を追加する

`HomeView.swift` の `AppHeaderView` 内に追加：

```swift
HStack {
    Image(systemName: "tshirt")
    VStack(alignment: .leading) {
        Text("myBabyOOTD")
            .font(.system(size: 18, weight: .bold))
        Text("今日のコーデを共有")
            .font(.system(size: 11))   // ← 追加
    }
}
```

**結果**: アプリ名の下に小さなサブタイトルが表示されます。

---

## Chapter 9. イベント処理のパターン集

### 9.1 Button の action

```swift
Button(action: {
    // タップ時の処理
}) {
    // 見た目（Label）
}
```

**パターン A: ローカル状態を切り替える**

```swift
@State private var isExpanded = false

Button("詳細を表示") {
    isExpanded.toggle()     // true ↔ false を切り替え
}
```

**パターン B: ViewModel の関数を呼ぶ**

```swift
Button("ログアウト") {
    authViewModel.signOut()
}
```

**パターン C: 非同期処理を実行する**

```swift
Button("天気を取得") {
    Task {
        await fetchWeather()
    }
}
```

### 9.2 onChange（値の変化を監視）

```swift
TextField("地域コード", text: $regionCode)
    .onChange(of: regionCode) { newValue in
        fetchWeather()   // 地域コードが変わったら天気を再取得
    }
```

**実コード**:  
`NewPostView.swift` で `selectedRegionIndex` が変わったら `fetchWeather()` を呼んでいます。

### 9.3 onAppear / onDisappear（画面表示/非表示時）

```swift
SomeView()
    .onAppear {
        print("このViewが表示された")
        loadData()
    }
    .onDisappear {
        print("このViewが消えた")
    }
```

**実コード**:  
`ProfileView.swift` では `.task { await loadProfile() }`（onAppear + 非同期）を使っています。  
`PostCardView.swift` では `.onAppear { if !itemsLoaded { loadItems() } }` で、初回表示時にFirestoreからアイテム情報を取得しています。

### 9.4 ジェスチャー（タップ以外）

```swift
Image("photo")
    .onLongPressGesture {
        print("長押しされた")
    }
```

---

## Chapter 10. 実践演習：myBabyOOTD の UI を改修する

### 演習 A: 新規投稿画面に「キャンセル確認」を追加する

`NewPostView.swift` の閉じるボタンに、未保存の内容がある場合は確認ダイアログを出したい。

```swift
// body の toolbar 部分
ToolbarItem(placement: .cancellationAction) {
    Button("閉じる") {
        if hasUnsavedChanges {
            showCloseConfirm = true
        } else {
            dismiss()
        }
    }
}
// ... 末尾に追加
.alert("下書きが保存されていません", isPresented: $showCloseConfirm) {
    Button("保存して閉じる", role: .none) {
        saveDraft()
        dismiss()
    }
    Button("破棄して閉じる", role: .destructive) {
        dismiss()
    }
    Button("キャンセル", role: .cancel) {}
}
```

**必要な追加**:
```swift
@State private var showCloseConfirm = false

private var hasUnsavedChanges: Bool {
    frontImage != nil && !draftSaved
}
```

### 演習 B: 検索画面の検索ボタンの見た目を変える

`SearchView.swift` の検索ボタン：

```swift
// Before
Button("検索") { ... }

// After
Button {
    performSearch()
} label: {
    HStack {
        Image(systemName: "magnifyingglass")
        Text("検索する")
    }
    .font(.system(size: 16, weight: .bold))
    .foregroundColor(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 14)
    .background(Color.accentRed)
    .cornerRadius(12)
}
```

**結果**: 横一杯の角丸赤ボタンに変わります。

### 演習 C: タイムラインの投稿カードにシェアボタンを追加する

`PostCardView.swift` の footer HStack に追加：

```swift
HStack {
    Button(action: onLike) { ... }
    
    // 追加
    Button {
        let text = "\(post.posterDisplayName ?? "")さんのコーデをチェック！"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        // ... 表示処理
    } label: {
        Image(systemName: "square.and.arrow.up")
            .foregroundColor(.gray)
    }
    
    Spacer()
    Button { showReportAlert = true } label: { ... }
}
```

**結果**: いいねボタンの隣に共有アイコンが表示されます。

---

## Appendix A. よく使う Modifier 早見表

| Modifier | 効果 | 実コード例 |
|----------|------|-----------|
| `.padding()` | 四方向に余白 | `.padding(.horizontal, 16)` |
| `.frame(...)` | サイズ指定 | `.frame(width: 100, height: 50)` |
| `.frame(maxWidth: .infinity)` | 横一杯に広げる | ボタンを幅一杯に |
| `.background(...)` | 背景色/View | `.background(Color.white)` |
| `.cornerRadius(12)` | 角を丸くする | カード風の見た目に |
| `.shadow(...)` | 影をつける | `.shadow(color: .black.opacity(0.1), radius: 8)` |
| `.font(...)` | フォント指定 | `.font(.system(size: 14, weight: .bold))` |
| `.foregroundColor(...)` | 文字/アイコン色 | `.foregroundColor(.secondary)` |
| `.clipShape(Circle())` | 円形にクリップ | アバター画像に |
| `.overlay(...)` | 上に重ねる | `.overlay(RoundedRectangle(...).stroke(...))` |
| `.disabled(...)` | 無効化 | `.disabled(!canPost)` |
| `.opacity(0.5)` | 不透明度 | 無効状態の見た目に |

---

## Appendix B. エラーが出たときのチェックリスト

| 症状 | 原因の可能性 | 対処法 |
|------|-------------|--------|
| `Cannot convert value of type 'X' to expected argument type 'Y'` | 型が合っていない | 変数の型を確認。`String` と `Int` を混ぜていないか |
| `Cannot find 'x' in scope` | 変数名のタイプミス | スペル確認。Swift は大文字小文字を区別する |
| `Missing argument for parameter 'x'` | 関数の引数が足りない | 引数ラベルを確認。Swift はラベルが必須の場合がある |
| `Escaping closure captures mutating 'self' parameter` | struct のメソッドでクロージャ内で self を変更 | `@State` な変数をローカルにコピーしてから変更 |
| `Thread 1: Fatal error: No ObservableObject of type X found` | `@EnvironmentObject` が注入されていない | 親 View で `.environmentObject(...)` を確認 |

---

## 次のステップ

1. **コードを読む**: このガイドを見ながら、実際の `Views/` フォルダのファイルを開いて対応関係を確認する。
2. **小さな変更を試す**: 色やサイズ、文字列を変えてビルドし、プレビュー/シミュレータで変化を確認する。
3. **コピー＆改変**: 既存の View（例：`PostCardView`）をコピーして名前を変え、必要な部分だけ削る/足す練習をする。
4. **MVVM の流れを追う**: ボタンタップ → ViewModel の関数 → Firestore アクセス → `@Published` 更新 → 画面再描画、という流れを1つ追ってみる。

---

*このガイドは myBabyOOTD のコードベースに基づいて作成されています。*  
*内容が膨大ですが、各 Chapter は独立して読める構成になっています。修正したい画面のファイルを開きながら、対応する Chapter を参照してください。*
