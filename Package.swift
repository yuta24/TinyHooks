// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "TinyHooks",
    platforms: [.macOS(.v11), .iOS(.v14)],
    products: [
        .library(
            name: "TinyHooks",
            targets: ["TinyHooks"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "TinyHooks",
            dependencies: []),
        .testTarget(
            name: "TinyHooksTests",
            dependencies: ["TinyHooks"]),
    ]
)
