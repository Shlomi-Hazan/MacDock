// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TLSChannelBindingExperiment",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "TLSChannelBindingProbe", targets: ["TLSChannelBindingProbe"])
    ],
    targets: [
        .executableTarget(
            name: "TLSChannelBindingProbe",
            path: "Sources/TLSChannelBindingProbe"
        )
    ]
)
