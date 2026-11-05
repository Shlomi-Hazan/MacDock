import SwiftUI
import Network
import MacDockShared

@MainActor
private final class DiagnosticConnectionSession {
    var decoder = ProtocolFrameDecoder()
}

@MainActor
final class MacDockBonjourAdvertiser: NSObject, NSApplicationDelegate {
    private var listener: NWListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "MacDock Mac", type: "_macdock._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleDiagnosticConnection(connection)
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
    }

    private func handleDiagnosticConnection(_ connection: NWConnection) {
        let session = DiagnosticConnectionSession()
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: .main)
        receiveDiagnostic(on: connection, session: session)
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
                            connection.send(content: acknowledgment, completion: .contentProcessed { _ in
                                connection.cancel()
                            })
                            return
                        }
                    }
                    if isComplete {
                        try session.decoder.finish()
                        connection.cancel()
                    } else {
                        self.receiveDiagnostic(on: connection, session: session)
                    }
                } catch {
                    connection.cancel()
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
