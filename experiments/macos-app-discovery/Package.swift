// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacOSAppDiscoveryExperiment",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacOSAppDiscovery", targets: ["AppDiscovery"]),
        .library(name: "AppDiscoveryCore", targets: ["AppDiscoveryCore"])
    ],
    targets: [
        .target(name: "AppDiscoveryCore"),
        .executableTarget(name: "AppDiscovery", dependencies: ["AppDiscoveryCore"]),
        .testTarget(name: "AppDiscoveryCoreTests", dependencies: ["AppDiscoveryCore"])
    ]
)
