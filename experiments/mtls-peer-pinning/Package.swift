// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MTLSPeerPinningExperiment",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MTLSPeerPinningCore", targets: ["MTLSPeerPinningCore"]),
        .executable(name: "MTLSPeerPinningProbe", targets: ["MTLSPeerPinningProbe"])
    ],
    targets: [
        .target(name: "MTLSPeerPinningCore"),
        .executableTarget(
            name: "MTLSPeerPinningProbe",
            dependencies: ["MTLSPeerPinningCore"],
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(name: "MTLSPeerPinningCoreTests", dependencies: ["MTLSPeerPinningCore"])
    ]
)
