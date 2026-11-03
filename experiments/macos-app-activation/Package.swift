// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacOSAppActivationExperiment",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacOSAppActivation", targets: ["AppActivation"]),
        .library(name: "AppActivationCore", targets: ["AppActivationCore"])
    ],
    targets: [
        .target(name: "AppActivationCore"),
        .executableTarget(name: "AppActivation", dependencies: ["AppActivationCore"]),
        .testTarget(name: "AppActivationCoreTests", dependencies: ["AppActivationCore"])
    ]
)
