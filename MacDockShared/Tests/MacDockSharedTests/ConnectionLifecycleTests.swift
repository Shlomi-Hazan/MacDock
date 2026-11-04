import Testing
@testable import MacDockShared

struct ConnectionLifecycleTests {
    @Test
    func initialStateIsDisconnected() {
        let state = ConnectionLifecycleState()

        #expect(state.phase == .disconnected)
        #expect(state.attempt == nil)
        #expect(state.failure == nil)
    }

    @Test
    func normalDiscoveryAndTransportSequenceIsDeterministic() {
        let state = reduce([
            .startDiscovery,
            .candidateDiscovered,
            .startConnection
        ])

        #expect(state.phase == .connecting)
        #expect(state.attempt == ConnectionAttempt(generation: 1))

        let connected = ConnectionLifecycleReducer.reduce(
            state,
            .transportConnected(state.attempt!)
        )
        #expect(connected.phase == .transportConnected)
        #expect(connected.failure == nil)
    }

    @Test
    func transportReadinessIsNotTrust() {
        let connecting = reduce([.startDiscovery, .startConnection])
        let connected = ConnectionLifecycleReducer.reduce(
            connecting,
            .transportConnected(connecting.attempt!)
        )

        #expect(connected.phase == .transportConnected)
        #expect(connected.failure == nil)
    }

    @Test
    func disconnectStartsAReconnectionGeneration() {
        let connected = connectedState()
        let previousAttempt = connected.attempt!
        let reconnecting = ConnectionLifecycleReducer.reduce(
            connected,
            .transportDisconnected(previousAttempt)
        )

        #expect(reconnecting.phase == .reconnecting)
        #expect(reconnecting.attempt == ConnectionAttempt(generation: 2))
        #expect(reconnecting.attempt != previousAttempt)
    }

    @Test
    func retryAndReconnectCreateAFreshAttempt() {
        let initialConnecting = reduce([
            .startDiscovery,
            .startConnection
        ])
        let failed = ConnectionLifecycleReducer.reduce(
            initialConnecting,
            .transportFailed(initialConnecting.attempt!, .transportUnavailable)
        )
        let reconnecting = ConnectionLifecycleReducer.reduce(failed, .retryRequested)
        let reconnectingConnection = ConnectionLifecycleReducer.reduce(reconnecting, .reconnectAttempt)

        #expect(failed.phase == .failed)
        #expect(failed.failure == .transportUnavailable)
        #expect(reconnecting.phase == .reconnecting)
        #expect(reconnecting.attempt == ConnectionAttempt(generation: 2))
        #expect(reconnectingConnection.phase == .connecting)
    }

    @Test
    func staleSuccessCannotConnectAReplacedAttempt() {
        let connected = connectedState()
        let reconnecting = ConnectionLifecycleReducer.reduce(
            connected,
            .transportDisconnected(connected.attempt!)
        )
        let staleSuccess = ConnectionLifecycleReducer.reduce(
            reconnecting,
            .transportConnected(ConnectionAttempt(generation: 1))
        )

        #expect(staleSuccess == reconnecting)
    }

    @Test
    func staleFailureCannotReplaceAReplacedAttempt() {
        let connecting = reduce([
            .startDiscovery,
            .startConnection
        ])
        let retrying = ConnectionLifecycleReducer.reduce(
            connecting,
            .transportFailed(connecting.attempt!, .transportUnavailable)
        )
        let newer = ConnectionLifecycleReducer.reduce(retrying, .retryRequested)
        let staleFailure = ConnectionLifecycleReducer.reduce(
            newer,
            .transportFailed(ConnectionAttempt(generation: 1), .timeout)
        )

        #expect(staleFailure == newer)
        #expect(staleFailure.phase == .reconnecting)
    }

    @Test
    func staleTimeoutCannotFailACurrentAttempt() {
        let reconnecting = ConnectionLifecycleReducer.reduce(
            connectedState(),
            .transportDisconnected(ConnectionAttempt(generation: 1))
        )
        let current = ConnectionLifecycleReducer.reduce(reconnecting, .reconnectAttempt)
        let afterStaleTimeout = ConnectionLifecycleReducer.reduce(
            current,
            .timeout(ConnectionAttempt(generation: 1))
        )

        #expect(afterStaleTimeout == current)
    }

    @Test
    func timeoutProducesARecoverableFailure() {
        let connecting = reduce([.startDiscovery, .startConnection])
        let failed = ConnectionLifecycleReducer.reduce(
            connecting,
            .timeout(connecting.attempt!)
        )

        #expect(failed.phase == .failed)
        #expect(failed.failure == .timeout)
    }

    @Test
    func discoveryTimeoutHasDiscoverySpecificFailure() {
        let discovering = reduce([.startDiscovery])
        let failed = ConnectionLifecycleReducer.reduce(
            discovering,
            .timeout(discovering.attempt!)
        )

        #expect(failed.phase == .failed)
        #expect(failed.failure == .discoveryUnavailable)
    }

    @Test
    func cancellationPreventsLaterCallbacksFromAdvancingState() {
        let connecting = reduce([.startDiscovery, .startConnection])
        let cancelled = ConnectionLifecycleReducer.reduce(connecting, .cancel)
        let afterCallback = ConnectionLifecycleReducer.reduce(
            cancelled,
            .transportConnected(connecting.attempt!)
        )

        #expect(cancelled.phase == .cancelled)
        #expect(afterCallback == cancelled)
    }

    @Test
    func duplicateCallbacksAndInvalidOrderingAreIgnored() {
        let initial = ConnectionLifecycleState()
        #expect(ConnectionLifecycleReducer.reduce(initial, .candidateDiscovered) == initial)
        #expect(ConnectionLifecycleReducer.reduce(initial, .startConnection) == initial)

        let connected = connectedState()
        let duplicate = ConnectionLifecycleReducer.reduce(
            connected,
            .transportConnected(connected.attempt!)
        )
        #expect(duplicate == connected)
    }

    @Test
    func resetReturnsToDisconnectedWithoutReusingGeneration() {
        let connecting = reduce([.startDiscovery, .startConnection])
        let reset = ConnectionLifecycleReducer.reduce(connecting, .reset)
        let next = ConnectionLifecycleReducer.reduce(reset, .startDiscovery)

        #expect(reset.phase == .disconnected)
        #expect(reset.attempt == nil)
        #expect(next.attempt == ConnectionAttempt(generation: 2))
    }

    @Test
    func cancellationCanBeExplicitlyRecovered() {
        let cancelled = ConnectionLifecycleReducer.reduce(
            reduce([.startDiscovery]),
            .cancel
        )
        let reconnecting = ConnectionLifecycleReducer.reduce(cancelled, .retryRequested)

        #expect(cancelled.phase == .cancelled)
        #expect(reconnecting.phase == .reconnecting)
        #expect(reconnecting.attempt == ConnectionAttempt(generation: 2))
    }

    @Test
    func generationOverflowFailsClosedAndCannotBeBypassedByReset() {
        let exhaustedInput = ConnectionLifecycleState(
            phase: .failed,
            attempt: ConnectionAttempt(generation: .max),
            failure: .timeout,
            nextAttemptGeneration: .max
        )

        let exhausted = ConnectionLifecycleReducer.reduce(exhaustedInput, .retryRequested)
        #expect(exhausted.phase == .generationExhausted)
        #expect(exhausted.failure == .generationExhausted)
        #expect(exhausted.attempt == nil)
        #expect(exhausted.nextAttemptGeneration == .max)

        let afterReset = ConnectionLifecycleReducer.reduce(exhausted, .reset)
        #expect(afterReset == exhausted)
        #expect(ConnectionLifecycleReducer.reduce(afterReset, .startDiscovery) == exhausted)
        #expect(
            ConnectionLifecycleReducer.reduce(
                exhausted,
                .transportConnected(ConnectionAttempt(generation: .max))
            ) == exhausted
        )
    }

    private func connectedState() -> ConnectionLifecycleState {
        let connecting = reduce([.startDiscovery, .startConnection])
        return ConnectionLifecycleReducer.reduce(
            connecting,
            .transportConnected(connecting.attempt!)
        )
    }

    private func reduce(_ events: [ConnectionLifecycleEvent]) -> ConnectionLifecycleState {
        events.reduce(ConnectionLifecycleState()) {
            ConnectionLifecycleReducer.reduce($0, $1)
        }
    }
}
