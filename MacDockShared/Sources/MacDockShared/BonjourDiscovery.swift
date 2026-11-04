import Foundation

public enum BonjourDiscoveryPhase: Equatable, Sendable {
    case idle
    case browsing
    case waiting
    case ready
    case failed
    case cancelled
}

public enum BonjourCandidateTrust: Equatable, Sendable {
    case untrusted
}

public struct BonjourCandidate: Equatable, Hashable, Identifiable, Sendable {
    public static let maximumFieldLength = 64
    public static let maximumIdentifierLength = maximumFieldLength * 3 + 2
    public let id: String
    public let displayName: String
    public let serviceType: String
    public let domain: String
    public let trust: BonjourCandidateTrust

    public init?(id: String, displayName: String, serviceType: String, domain: String) {
        guard !id.isEmpty && id.count <= Self.maximumIdentifierLength else { return nil }
        guard [displayName, serviceType, domain].allSatisfy({ !$0.isEmpty && $0.count <= Self.maximumFieldLength }) else { return nil }
        self.id = id
        self.displayName = displayName
        self.serviceType = serviceType
        self.domain = domain
        trust = .untrusted
    }
}

public struct BonjourDiscoveryState: Equatable, Sendable {
    public static let maximumCandidateCount = 32
    public let phase: BonjourDiscoveryPhase
    public let candidates: [BonjourCandidate]

    public init(phase: BonjourDiscoveryPhase = .idle, candidates: [BonjourCandidate] = []) {
        self.phase = phase
        self.candidates = Array(candidates.prefix(Self.maximumCandidateCount))
    }
}

public enum BonjourDiscoveryEvent: Equatable, Sendable {
    case start
    case browserReady
    case browserWaiting
    case browserFailed
    case browserCancelled
    case candidateAppeared(BonjourCandidate)
    case candidateDisappeared(String)
    case stop
}

public enum BonjourDiscoveryReducer {
    public static func reduce(_ state: BonjourDiscoveryState, _ event: BonjourDiscoveryEvent) -> BonjourDiscoveryState {
        switch event {
        case .start:
            return BonjourDiscoveryState(phase: .browsing)
        case .browserReady:
            guard state.phase == .browsing || state.phase == .waiting else { return state }
            return BonjourDiscoveryState(phase: .ready, candidates: state.candidates)
        case .browserWaiting:
            guard state.phase == .browsing || state.phase == .ready else { return state }
            return BonjourDiscoveryState(phase: .waiting, candidates: state.candidates)
        case .browserFailed:
            return BonjourDiscoveryState(phase: .failed)
        case .browserCancelled, .stop:
            return BonjourDiscoveryState(phase: .cancelled)
        case let .candidateAppeared(candidate):
            guard state.phase == .browsing || state.phase == .waiting || state.phase == .ready else { return state }
            guard !state.candidates.contains(where: { $0.id == candidate.id }) else { return state }
            guard state.candidates.count < BonjourDiscoveryState.maximumCandidateCount else { return state }
            return BonjourDiscoveryState(phase: state.phase, candidates: state.candidates + [candidate])
        case let .candidateDisappeared(id):
            guard state.phase == .browsing || state.phase == .waiting || state.phase == .ready else { return state }
            return BonjourDiscoveryState(phase: state.phase, candidates: state.candidates.filter { $0.id != id })
        }
    }
}
