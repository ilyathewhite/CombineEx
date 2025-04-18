// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineEx",
    platforms: [
        .macOS("12.0"), .iOS("15.0"), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "CombineEx",
            targets: ["CombineEx"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ilyathewhite/FoundationEx.git", .upToNextMinor(from: "1.0.5"))
    ],
    targets: [
        .target(
            name: "CombineEx",
            dependencies: ["FoundationEx"]
        )
    ]
)
