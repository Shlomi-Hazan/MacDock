import SwiftUI
import Network
import MacDockShared

@MainActor
private final class DiagnosticConnectionSession {
    var decoder = ProtocolFrameDecoder()
    var timeoutWorkItem: DispatchWorkItem?
    var isFinished = false
}

@MainActor
final class MacDockBonjourAdvertiser: NSObject, NSApplicationDelegate {
    private static let maximumConcurrentDiagnosticConnections = 4
    private static let diagnosticIdleTimeout: TimeInterval = 10
    private var listener: NWListener?
    private var activeConnectionIDs = Set<ObjectIdentifier>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "MacDock Mac", type: "_macdock._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.acceptDiagnosticConnection(connection)
                }
            }
            listener.stateUpdateHandler = { state in
                if case .failed = state { listener.cancel() }
            }
            self.listener = listener
            listener.start(queue: .main)
        } catch {
            listener = nil
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        listener?.cancel()
        listener = nil
        activeConnectionIDs.removeAll()
    }

    private func acceptDiagnosticConnection(_ connection: NWConnection) {
        let connectionID = ObjectIdentifier(connection)
        guard activeConnectionIDs.count < Self.maximumConcurrentDiagnosticConnections else {
            connection.cancel()
            return
        }

        activeConnectionIDs.insert(connectionID)
        let session = DiagnosticConnectionSession()
        session.timeoutWorkItem = DispatchWorkItem { [weak self, weak connection] in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection else { return }
                self.finishDiagnosticConnection(connection, session: session)
            }
        }
        if let timeoutWorkItem = session.timeoutWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.diagnosticIdleTimeout, execute: timeoutWorkItem)
        }

        connection.stateUpdateHandler = { state in
            if case .failed = state {
                Task { @MainActor [weak self, weak connection] in
                    guard let self, let connection else { return }
                    self.finishDiagnosticConnection(connection, session: session)
                }
            }
        }
        connection.start(queue: .main)
        receiveDiagnostic(on: connection, session: session)
    }

    private func finishDiagnosticConnection(
        _ connection: NWConnection,
        session: DiagnosticConnectionSession
    ) {
        guard !session.isFinished else { return }
        session.isFinished = true
        session.timeoutWorkItem?.cancel()
        session.timeoutWorkItem = nil
        activeConnectionIDs.remove(ObjectIdentifier(connection))
        connection.cancel()
    }

    private func receiveDiagnostic(
        on connection: NWConnection,
        session: DiagnosticConnectionSession
    ) {
        connection.receive(
            minimumIncompleteLength: 1,
            maximumLength: ProtocolFrameCodec.headerLength + ProtocolFrameCodec.maximumEncodedFramePayloadLength
        ) { [weak self, weak connection] data, _, isComplete, _ in
            Task { @MainActor [weak self, weak connection] in
                guard let self, let connection else { return }
                do {
                    if let data {
                        let envelopes = try session.decoder.append(data)
                        for envelope in envelopes {
                            guard try TransportDiagnosticCodec.decode(envelope) == .hello else {
                                connection.cancel()
                                return
                            }
                            let acknowledgment = try ProtocolFrameCodec.encode(
                                TransportDiagnosticCodec.acknowledgmentEnvelope()
                            )
                            connection.send(content: acknowledgment, completion: .contentProcessed { [weak self, weak connection] _ in
                                Task { @MainActor [weak self, weak connection] in
                                    guard let self, let connection else { return }
                                    self.finishDiagnosticConnection(connection, session: session)
                                }
                            })
                            return
                        }
                    }
                    if isComplete {
                        try session.decoder.finish()
                        self.finishDiagnosticConnection(connection, session: session)
                    } else {
                        self.receiveDiagnostic(on: connection, session: session)
                    }
                } catch {
                    self.finishDiagnosticConnection(connection, session: session)
                }
            }
        }
    }
}

@main
struct MacDockMacApp: App {
    @NSApplicationDelegateAdaptor(MacDockBonjourAdvertiser.self) private var advertiser
    var body: some Scene {
        MenuBarExtra("MacDock", systemImage: "dock.rectangle") {
            Text("MacDock Foundation")
                .font(.headline)

            Text(MacDockFoundationInfo.current.stageLabel)
                .foregroundStyle(.secondary)

            Text("Companion shell ready")
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit MacDock") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
