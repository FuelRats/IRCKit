// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "IRCKit",
    platforms: [
        .macOS("14.0")
    ],
    products: [
        .library(
            name: "IRCKit",
            targets: ["IRCKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.97.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.36.0"),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: "1.33.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.9.0"),
    ],
    targets: [
        .target(
            name: "IRCKit",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                "CryptoSwift",
            ]),
        .testTarget(
            name: "IRCKitTests",
            dependencies: ["IRCKit"]),
    ]
)
