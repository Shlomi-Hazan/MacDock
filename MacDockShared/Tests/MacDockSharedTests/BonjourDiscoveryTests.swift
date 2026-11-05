import Testing
@testable import MacDockShared

struct BonjourDiscoveryTests {
    private let candidate = BonjourCandidate(
        id: "_macdock._tcp|MacDock|local.", displayName: "MacDock",
        serviceType: "_macdock._tcp", domain: "local."
    )!

    @Test
    func candidateLifecycleIsDeterministic() {
        var state = BonjourDiscoveryReducer.reduce(.init(), .start)
        state = BonjourDiscoveryReducer.reduce(state, .browserReady)
        state = BonjourDiscoveryReducer.reduce(state, .candidateAppeared(candidate))
        #expect(state.phase == .ready)
        #expect(state.candidates == [candidate])
        state = BonjourDiscoveryReducer.reduce(state, .candidateDisappeared(candidate.id))
        #expect(state.candidates.isEmpty)
    }

    @Test
    func duplicateCandidatesAreIgnored() {
        let started = BonjourDiscoveryReducer.reduce(.init(), .start)
        let once = BonjourDiscoveryReducer.reduce(started, .candidateAppeared(candidate))
        let twice = BonjourDiscoveryReducer.reduce(once, .candidateAppeared(candidate))
        #expect(twice.candidates == [candidate])
    }

    @Test
    func cancellationRejectsStaleCandidateEvents() {
        let started = BonjourDiscoveryReducer.reduce(.init(), .start)
        let cancelled = BonjourDiscoveryReducer.reduce(started, .stop)
        let stale = BonjourDiscoveryReducer.reduce(cancelled, .candidateAppeared(candidate))
        #expect(stale.phase == .cancelled)
        #expect(stale.candidates.isEmpty)
    }

    @Test
    func failureCanBeRetriedAndClearsOldCandidates() {
        let started = BonjourDiscoveryReducer.reduce(.init(), .start)
        let failed = BonjourDiscoveryReducer.reduce(started, .browserFailed)
        let retried = BonjourDiscoveryReducer.reduce(failed, .start)
        #expect(failed.phase == .failed)
        #expect(retried.phase == .browsing)
        #expect(retried.candidates.isEmpty)
    }

    @Test
    func candidateMetadataIsBounded() {
        let oversizedField = String(repeating: "x", count: BonjourCandidate.maximumFieldLength + 1)
        #expect(BonjourCandidate(id: "candidate", displayName: oversizedField, serviceType: "_macdock._tcp", domain: "local.") == nil)

        let oversizedIdentifier = String(repeating: "x", count: BonjourCandidate.maximumIdentifierLength + 1)
        #expect(BonjourCandidate(id: oversizedIdentifier, displayName: "MacDock", serviceType: "_macdock._tcp", domain: "local.") == nil)
    }

    @Test
    func discoveryNeverCreatesTrust() {
        #expect(candidate.trust == .untrusted)
    }
}
