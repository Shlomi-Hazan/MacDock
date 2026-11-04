import Foundation

public struct ConnectionAttempt: Equatable, Hashable, Sendable {
    public let generation: UInt64

    public init(generation: UInt64) {
        self.generation = generation
    }
}

public enum ConnectionLifecyclePhase: Equatable, Sendable {
    case disconnected
    case discovering
    case connecting
    case transportConnected
    case reconnecting
    case failed
    case cancelled
    case generationExhausted
}

public enum ConnectionFailureReason: Equatable, Sendable {
    case discoveryUnavailable
    case transportUnavailable
    case timeout
    case generationExhausted
}

public struct ConnectionLifecycleState: Equatable, Sendable {
    public let phase: ConnectionLifecyclePhase
    public let attempt: ConnectionAttempt?
    public let failure: ConnectionFailureReason?
    public let nextAttemptGeneration: UInt64

    public init() {
        phase = .disconnected
        attempt = nil
        failure = nil
        nextAttemptGeneration = 0
    }

    internal init(
        phase: ConnectionLifecyclePhase,
        attempt: ConnectionAttempt?,
        failure: ConnectionFailureReason?,
        nextAttemptGeneration: UInt64
    ) {
        self.phase = phase
        self.attempt = attempt
        self.failure = failure
        self.nextAttemptGeneration = nextAttemptGeneration
    }
}

public enum ConnectionLifecycleEvent: Equatable, Sendable {
    case startDiscovery
    case candidateDiscovered
    case startConnection
    case transportConnected(ConnectionAttempt)
    case transportFailed(ConnectionAttempt, ConnectionFailureReason)
    case transportDisconnected(ConnectionAttempt)
    case retryRequested
    case reconnectAttempt
    case timeout(ConnectionAttempt)
    case cancel
    case reset
}

public enum ConnectionLifecycleReducer {
    public static func reduce(
        _ state: ConnectionLifecycleState,
        _ event: ConnectionLifecycleEvent
    ) -> ConnectionLifecycleState {
        switch event {
        case .startDiscovery:
            guard state.phase != .discovering else { return state }
            return beginAttempt(from: state, phase: .discovering)

        case .candidateDiscovered:
            guard state.phase == .discovering else { return state }
            return state

        case .startConnection:
            guard state.phase == .discovering || state.phase == .reconnecting else {
                return state
            }
            return state.with(phase: .connecting, failure: nil)

        case let .transportConnected(attempt):
            guard state.phase == .connecting, state.attempt == attempt else {
                return state
            }
            return state.with(phase: .transportConnected, failure: nil)

        case let .transportFailed(attempt, reason):
            guard
                (state.phase == .connecting || state.phase == .reconnecting),
                state.attempt == attempt
            else {
                return state
            }
            return state.with(phase: .failed, failure: reason)

        case let .transportDisconnected(attempt):
            guard state.phase == .transportConnected, state.attempt == attempt else {
                return state
            }
            return beginAttempt(from: state, phase: .reconnecting)

        case .retryRequested:
            guard
                state.phase == .failed ||
                state.phase == .cancelled ||
                state.phase == .disconnected
            else {
                return state
            }
            return beginAttempt(from: state, phase: .reconnecting)

        case .reconnectAttempt:
            guard state.phase == .reconnecting else { return state }
            return state.with(phase: .connecting, failure: nil)

        case let .timeout(attempt):
            guard
                (state.phase == .discovering ||
                    state.phase == .connecting ||
                    state.phase == .reconnecting),
                state.attempt == attempt
            else {
                return state
            }
            let reason: ConnectionFailureReason = state.phase == .discovering
                ? .discoveryUnavailable
                : .timeout
            return state.with(phase: .failed, failure: reason)

        case .cancel:
            guard
                state.phase == .discovering ||
                state.phase == .connecting ||
                state.phase == .transportConnected ||
                state.phase == .reconnecting
            else {
                return state
            }
            return state.with(phase: .cancelled, failure: nil)

        case .reset:
            if state.phase == .generationExhausted || state.nextAttemptGeneration == .max {
                return ConnectionLifecycleState(
                    phase: .generationExhausted,
                    attempt: nil,
                    failure: .generationExhausted,
                    nextAttemptGeneration: .max
                )
            }
            return ConnectionLifecycleState(
                phase: .disconnected,
                attempt: nil,
                failure: nil,
                nextAttemptGeneration: state.nextAttemptGeneration
            )
        }
    }

    private static func beginAttempt(
        from state: ConnectionLifecycleState,
        phase: ConnectionLifecyclePhase
    ) -> ConnectionLifecycleState {
        guard state.nextAttemptGeneration < .max else {
            return ConnectionLifecycleState(
                phase: .generationExhausted,
                attempt: nil,
                failure: .generationExhausted,
                nextAttemptGeneration: .max
            )
        }

        let nextGeneration = state.nextAttemptGeneration + 1
        let attempt = ConnectionAttempt(generation: nextGeneration)

        return ConnectionLifecycleState(
            phase: phase,
            attempt: attempt,
            failure: nil,
            nextAttemptGeneration: nextGeneration
        )
    }
}

private extension ConnectionLifecycleState {
    func with(
        phase: ConnectionLifecyclePhase,
        failure: ConnectionFailureReason?
    ) -> ConnectionLifecycleState {
        ConnectionLifecycleState(
            phase: phase,
            attempt: attempt,
            failure: failure,
            nextAttemptGeneration: nextAttemptGeneration
        )
    }
}
