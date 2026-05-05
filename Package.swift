// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "NodeGetMonitor",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NodeGetCore",
            targets: ["NodeGetCore"]
        )
    ],
    targets: [
        .target(
            name: "NodeGetCore"
        ),
        .testTarget(
            name: "NodeGetCoreTests",
            dependencies: ["NodeGetCore"]
        )
    ]
)
