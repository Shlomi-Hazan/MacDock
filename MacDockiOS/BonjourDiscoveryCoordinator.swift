import Foundation
import Network
import MacDockShared

@MainActor
final class BonjourDiscoveryCoordinator: ObservableObject {
    static let serviceType = "_macdock._tcp"
    @Published private(set) var state = BonjourDiscoveryState()
    @Published private(set) var transportState = TransportDiagnosticState()
    private var browser: NWBrowser?
    private var generation: UInt64 = 0
    private var candidateEndpoints: [String: NWEndpoint] = [:]
    private var connection: NWConnection?
    private var transportGeneration: UInt64 = 0
    private var timeoutWorkItem: DispatchWorkItem?
    private var transportDecoder = ProtocolFrameDecoder()

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
        cancelTransport()
        state = BonjourDiscoveryReducer.reduce(state, .stop)
    }

    func connect(to candidate: BonjourCandidate) {
        guard let endpoint = candidateEndpoints[candidate.id] else {
            transportState = TransportDiagnosticReducer.reduce(.init(), .failed)
            return
        }

        transportGeneration &+= 1
        let currentGeneration = transportGeneration
        timeoutWorkItem?.cancel()
        connection?.cancel()
        transportDecoder = ProtocolFrameDecoder()
        let connection = NWConnection(to: endpoint, using: .tcp)
        self.connection = connection
        transportState = TransportDiagnosticReducer.reduce(.init(), .connecting)

        connection.stateUpdateHandler = { [weak self, weak connection] connectionState in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection, self.transportGeneration == currentGeneration else { return }
                switch connectionState {
                case .ready:
                    self.transportState = TransportDiagnosticReducer.reduce(.init(), .ready)
                    self.sendDiagnosticHello(
                        on: connection,
                        generation: currentGeneration
                    )
                case .failed, .waiting:
                    self.failTransport(generation: currentGeneration)
                case .cancelled:
                    if !self.transportState.diagnosticExchangeCompleted,
                       self.transportState.phase != .failed {
                        self.transportState = TransportDiagnosticReducer.reduce(.init(), .cancelled)
                    }
                default:
                    break
                }
            }
        }

        connection.start(queue: .main)
        let timeout = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.transportGeneration == currentGeneration else { return }
                self.failTransport(generation: currentGeneration)
            }
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
    }

    func cancelTransport() {
        transportGeneration &+= 1
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        connection?.cancel()
        connection = nil
        transportState = TransportDiagnosticReducer.reduce(.init(), .cancelled)
    }

    private func sendDiagnosticHello(
        on connection: NWConnection,
        generation: UInt64
    ) {
        do {
            let hello = try ProtocolFrameCodec.encode(TransportDiagnosticCodec.helloEnvelope())
            connection.send(content: hello, completion: .contentProcessed { [weak self] error in
                guard error == nil else {
                    Task { @MainActor [weak self] in
                        self?.failTransport(generation: generation)
                    }
                    return
                }
                Task { @MainActor [weak self, weak connection] in
                    guard let self, let connection else { return }
                    self.receiveTransport(on: connection, generation: generation)
                }
            })
        } catch {
            failTransport(generation: generation)
        }
    }

    private func receiveTransport(on connection: NWConnection, generation: UInt64) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: ProtocolFrameCodec.headerLength + ProtocolFrameCodec.maximumEncodedFramePayloadLength
        ) { [weak self, weak connection] data, _, isComplete, _ in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection, self.transportGeneration == generation else { return }
                do {
                    if let data {
                        let envelopes = try self.transportDecoder.append(data)
                        for envelope in envelopes {
                            guard try TransportDiagnosticCodec.decode(envelope) == .acknowledgment else {
                                self.failTransport(generation: generation)
                                return
                            }
                            self.timeoutWorkItem?.cancel()
                            self.transportState = TransportDiagnosticReducer.reduce(
                                self.transportState,
                                .acknowledgmentValidated
                            )
                        }
                    }
                    if isComplete {
                        try self.transportDecoder.finish()
                        self.transportState = TransportDiagnosticReducer.reduce(
                            self.transportState,
                            .connectionClosed
                        )
                        if self.transportState.phase == .failed {
                            self.failTransport(generation: generation)
                        } else {
                            self.timeoutWorkItem?.cancel()
                            self.timeoutWorkItem = nil
                            self.connection = nil
                        }
                    } else {
                        self.receiveTransport(on: connection, generation: generation)
                    }
                } catch {
                    self.failTransport(generation: generation)
                }
            }
        }
    }

    private func failTransport(generation: UInt64) {
        guard transportGeneration == generation else { return }
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        connection?.cancel()
        connection = nil
        transportState = TransportDiagnosticReducer.reduce(.init(), .failed)
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
        candidateEndpoints = Dictionary(uniqueKeysWithValues: results.compactMap { result in
            guard let candidate = candidate(from: result) else { return nil }
            return (candidate.id, result.endpoint)
        })
        for candidate in candidates {
            state = BonjourDiscoveryReducer.reduce(state, .candidateAppeared(candidate))
        }
        for candidate in state.candidates where !currentIDs.contains(candidate.id) {
            state = BonjourDiscoveryReducer.reduce(state, .candidateDisappeared(candidate.id))
            candidateEndpoints.removeValue(forKey: candidate.id)
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
