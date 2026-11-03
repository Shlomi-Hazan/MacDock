import CryptoKit
import Foundation

public enum Availability: String, Codable, Sendable {
    case launchableCandidate
    case incompleteMetadata
    case inaccessible
}

public struct ApplicationIdentity: Codable, Equatable, Sendable {
    public let bundleIdentifier: String?
    public let installationDigest: String

    public init(bundleIdentifier: String?, canonicalURL: URL) {
        self.bundleIdentifier = bundleIdentifier?.isEmpty == false ? bundleIdentifier : nil
        let canonicalPath = canonicalURL.standardizedFileURL.resolvingSymlinksInPath().path
        let digest = SHA256.hash(data: Data(canonicalPath.utf8))
        self.installationDigest = digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Deterministic experiment key only. A plain path digest is not approved as a privacy-preserving wire identifier.
    public var experimentalKey: String {
        let bundle = bundleIdentifier ?? "unknown-bundle"
        return "app:\(bundle):\(installationDigest)"
    }
}

public struct DiscoveredApplication: Codable, Equatable, Sendable {
    public let identity: ApplicationIdentity
    public let displayName: String?
    public let bundleIdentifier: String?
    public let availability: Availability
    public let isRunning: Bool
    public let hasIcon: Bool

    public init(identity: ApplicationIdentity, displayName: String?, bundleIdentifier: String?, availability: Availability, isRunning: Bool, hasIcon: Bool) {
        self.identity = identity
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.availability = availability
        self.isRunning = isRunning
        self.hasIcon = hasIcon
    }
}
