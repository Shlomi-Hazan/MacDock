// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacDockShared",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "MacDockShared", targets: ["MacDockShared"])],
    targets: [
        .target(name: "MacDockShared"),
        .testTarget(name: "MacDockSharedTests", dependencies: ["MacDockShared"])
    ]
)
