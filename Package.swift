// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clerk",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Clerk", targets: ["Clerk"])
    ],
    dependencies: [
        // Hot key support
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
        // Keychain wrapper
        .package(url: "https://github.com/evgenyneu/keychain-swift.git", from: "20.0.0"),
        // Markdown rendering
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Clerk",
            dependencies: [
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "KeychainSwift", package: "keychain-swift"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Clerk"
        ),
        .testTarget(
            name: "ClerkTests",
            dependencies: ["Clerk"],
            path: "ClerkTests"
        ),
    ]
)
