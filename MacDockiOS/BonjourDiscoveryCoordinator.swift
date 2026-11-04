import Foundation
import Network
import MacDockShared

@MainActor
final class BonjourDiscoveryCoordinator: ObservableObject {
    static let serviceType = "_macdock._tcp"
    @Published private(set) var state = BonjourDiscoveryState()
    private var browser: NWBrowser?
    private var generation: UInt64 = 0

    func start() {
        generation &+= 1
        let currentGeneration = generation
        browser?.cancel()
        browser = nil
        state = BonjourDiscoveryReducer.reduce(state, .start)

        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: .tcp)
        browser.stateUpdateHandler = { [weak self] browserState in
            Task { @MainActor [weak self] in
                guard let self, self.generation == currentGeneration else { return }
                self.handle(browserState)
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == currentGeneration else { return }
                self.updateCandidates(from: results)
            }
        }
        self.browser = browser
        browser.start(queue: .main)
    }

    func stop() {
        generation &+= 1
        browser?.cancel()
        browser = nil
        state = BonjourDiscoveryReducer.reduce(state, .stop)
    }

    private func handle(_ browserState: NWBrowser.State) {
        switch browserState {
        case .ready: state = BonjourDiscoveryReducer.reduce(state, .browserReady)
        case .waiting: state = BonjourDiscoveryReducer.reduce(state, .browserWaiting)
        case .failed: state = BonjourDiscoveryReducer.reduce(state, .browserFailed)
        case .cancelled: state = BonjourDiscoveryReducer.reduce(state, .browserCancelled)
        case .setup: break
        @unknown default: state = BonjourDiscoveryReducer.reduce(state, .browserFailed)
        }
    }

    private func updateCandidates(from results: Set<NWBrowser.Result>) {
        let candidates = results.compactMap(candidate(from:))
        let currentIDs = Set(candidates.map(\.id))
        for candidate in candidates {
            state = BonjourDiscoveryReducer.reduce(state, .candidateAppeared(candidate))
        }
        for candidate in state.candidates where !currentIDs.contains(candidate.id) {
            state = BonjourDiscoveryReducer.reduce(state, .candidateDisappeared(candidate.id))
        }
    }

    private func candidate(from result: NWBrowser.Result) -> BonjourCandidate? {
        guard case let .service(name: name, type: type, domain: domain, interface: _) = result.endpoint else { return nil }
        let boundedName = String(name.prefix(BonjourCandidate.maximumFieldLength))
        let boundedType = String(type.prefix(BonjourCandidate.maximumFieldLength))
        let boundedDomain = String(domain.prefix(BonjourCandidate.maximumFieldLength))
        return BonjourCandidate(
            id: "\(boundedType)|\(boundedName)|\(boundedDomain)", displayName: boundedName,
            serviceType: boundedType, domain: boundedDomain
        )
    }
}
