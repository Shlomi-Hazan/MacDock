// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IOSLifecycleStateExperiment",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "LifecycleState", targets: ["LifecycleState"])],
    targets: [
        .target(name: "LifecycleState", path: "Sources"),
        .testTarget(name: "LifecycleStateTests", dependencies: ["LifecycleState"], path: "Tests")
    ]
)
