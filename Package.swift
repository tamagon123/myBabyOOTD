// swift-tools-version: 5.9
// このファイルはSPM依存関係の参照用です。
// XcodeプロジェクトではFile > Add Package Dependencies から追加してください。
import PackageDescription

let package = Package(
    name: "myBabyCode",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.0.0"
        ),
        .package(
            url: "https://github.com/google/GoogleSignIn-iOS.git",
            from: "7.0.0"
        )
    ],
    targets: [
        .target(
            name: "myBabyCode",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ]
        )
    ]
)
