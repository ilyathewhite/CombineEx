// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineEx",
    platforms: [
        .macOS(.v11), .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "CombineEx",
            targets: ["CombineEx"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ilyathewhite/FoundationEx.git", .branch("main"))
    ],
    targets: [
        .target(
            name: "CombineEx",
            dependencies: ["FoundationEx"]
        ),
        .testTarget(
            name: "CombineExTests",
            dependencies: ["CombineEx"]
        )
    ]
)
