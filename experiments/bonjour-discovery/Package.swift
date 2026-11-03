// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BonjourDiscoveryExperiment",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "BonjourAdvertiser", targets: ["BonjourAdvertiser"]),
        .executable(name: "BonjourBrowser", targets: ["BonjourBrowser"])
    ],
    targets: [
        .executableTarget(name: "BonjourAdvertiser"),
        .executableTarget(name: "BonjourBrowser")
    ]
)
