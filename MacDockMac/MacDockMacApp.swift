import SwiftUI
import Network
import MacDockShared

@MainActor
final class MacDockBonjourAdvertiser: NSObject, NSApplicationDelegate {
    private var listener: NWListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "MacDock Mac", type: "_macdock._tcp")
            listener.newConnectionHandler = { [weak self] connection in
                self?.handleDiagnosticConnection(connection)
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
        var decoder = ProtocolFrameDecoder()
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: .main)

        func receive() {
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: ProtocolFrameCodec.headerLength + ProtocolFrameCodec.maximumEncodedFramePayloadLength
            ) { data, _, isComplete, _ in
                do {
                    if let data {
                        let envelopes = try decoder.append(data)
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
                        try decoder.finish()
                        connection.cancel()
                    } else {
                        receive()
                    }
                } catch {
                    connection.cancel()
                }
            }
        }

        receive()
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
