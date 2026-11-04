import Foundation

public struct MacDockFoundationInfo: Equatable, Sendable {
    public let productVersion: String
    public let stage: String

    public init(productVersion: String, stage: String) {
        self.productVersion = productVersion
        self.stage = stage
    }

    public var stageLabel: String { "Stage: \(stage)" }

    public static let current = MacDockFoundationInfo(
        productVersion: "0.1.0",
        stage: "Foundation"
    )
}
