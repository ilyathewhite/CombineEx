// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineEx",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13)
    ],
    products: [
        .library(
            name: "CombineEx",
            targets: ["CombineEx"]),
    ],
    dependencies: [
        .package(name: "FoundationEx", url: "https://github.com/RocketLaunchpad/FoundationEx.git", from: "1.0.0")

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
