// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IRCKit",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "IRCKit",
            targets: ["IRCKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: Version(2, 22, 0)),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: Version (2, 9, 1)),
        .package(url: "https://github.com/apple/swift-nio-extras.git", from: Version(1, 7, 0)),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: Version(1, 4, 0)),
        .package(url: "https://github.com/gonzalezreal/DefaultCodable.git", from: Version(1, 2, 0))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "IRCKit",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "NIOExtras", package: "swift-nio-extras"),
                "CryptoSwift",
                "DefaultCodable"
            ]),
        .testTarget(
            name: "IRCKitTests",
            dependencies: ["IRCKit"]),
    ]
)
