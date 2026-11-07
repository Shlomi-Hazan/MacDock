import Foundation

public enum PeerTrustState: Equatable, Sendable {
    case untrusted
    case pending(sessionID: String)
    case committed(peerFingerprint: String)
    case revoked
    case recoveryRequired
}

public enum TrustEvent: Equatable, Sendable {
    case begin(sessionID: String)
    case confirm(peerFingerprint: String)
    case revoke
    case identityChanged
    case interrupted
}

public struct TrustStateMachine: Sendable {
    public private(set) var state: PeerTrustState = .untrusted

    public init() {}

    @discardableResult
    public mutating func apply(_ event: TrustEvent) -> Bool {
        switch (state, event) {
        case (.untrusted, .begin(let sessionID)) where !sessionID.isEmpty:
            state = .pending(sessionID: sessionID)
            return true
        case (.pending, .confirm(let fingerprint)) where !fingerprint.isEmpty:
            state = .committed(peerFingerprint: fingerprint)
            return true
        case (.committed, .revoke):
            state = .revoked
            return true
        case (.committed, .identityChanged):
            state = .recoveryRequired
            return true
        case (.pending, .interrupted):
            state = .recoveryRequired
            return true
        default:
            return false
        }
    }
}
