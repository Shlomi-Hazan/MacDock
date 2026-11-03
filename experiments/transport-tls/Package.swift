// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TransportTLSExperiment",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TransportTLSCore", targets: ["TransportTLSCore"]),
        .executable(name: "TransportTLSAdvertiser", targets: ["TransportTLSAdvertiser"])
    ],
    targets: [
        .target(name: "TransportTLSCore"),
        .executableTarget(
            name: "TransportTLSAdvertiser",
            dependencies: ["TransportTLSCore"],
            linkerSettings: [.linkedFramework("Security")]
        ),
        .testTarget(name: "TransportTLSCoreTests", dependencies: ["TransportTLSCore"])
    ]
)
