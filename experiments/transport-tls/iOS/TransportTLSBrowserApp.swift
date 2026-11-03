import CryptoKit
import Network
import Security
import SwiftUI

private let serviceType = "_macdock-tls._tcp"
private let expectedHello = Data("IPHONE-HELLO/1\n".utf8)
private let expectedAcknowledgment = Data("MAC-ACK/1\n".utf8)

private func normalizedFingerprint(_ value: String) -> String {
    value.filter { $0.isHexDigit }.lowercased()
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

@MainActor
final class TransportTLSBrowserModel: ObservableObject {
    @Published var fingerprint = ""
    @Published private(set) var state = "Not started"
    @Published private(set) var serviceCount = 0
    @Published private(set) var messageState = "No message exchange"
    @Published private(set) var pathSummary = "Path unknown"

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var endpoint: NWEndpoint?
    private var timeoutWorkItem: DispatchWorkItem?
    private var exchangeCompleted = false

    func startBrowsing() {
        browser?.cancel()
        connection?.cancel()
        serviceCount = 0
        endpoint = nil
        messageState = "No message exchange"
        state = "Starting browser"

        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self, weak browser] browserState in
            Task { @MainActor in
                guard let self else { return }
                guard self.browser === browser else { return }
                switch browserState {
                case .ready: self.state = "Ready"
                case .waiting(let error): self.state = "Waiting: \(error.localizedDescription)"
                case .failed(let error): self.state = "Failed: \(error.localizedDescription)"
                case .cancelled: self.state = "Cancelled"
                default: break
                }
            }
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            Task { @MainActor in
                guard let self, self.browser === browser else { return }
                self.serviceCount = results.count
                self.endpoint = results.first?.endpoint
            }
        }
        browser.start(queue: .main)
    }

    func connect() {
        guard let endpoint else { state = "No service selected"; return }
        let expected = normalizedFingerprint(fingerprint)
        guard expected.count == 64 else { state = "Enter a 64-character SHA-256 fingerprint"; return }

        connection?.cancel()
        exchangeCompleted = false
        messageState = "Connecting"
        state = "Connecting"
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
            let trustRef = sec_trust_copy_ref(trust).takeRetainedValue()
            guard let certificate = SecTrustGetCertificateAtIndex(trustRef, 0) else {
                complete(false)
                return
            }
            let certificateData = SecCertificateCopyData(certificate) as Data
            complete(sha256Hex(certificateData) == expected)
        }, DispatchQueue.main)

        let connection = NWConnection(to: endpoint, using: NWParameters(tls: tls, tcp: NWProtocolTCP.Options()))
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] connectionState in
            Task { @MainActor in
                guard let self, let connection else { return }
                guard self.connection === connection else { return }
                switch connectionState {
                case .ready:
                    self.state = "TLS Ready — peer fingerprint verified"
                    self.pathSummary = self.pathDescription(connection.currentPath)
                    self.sendFrame(on: connection, message: expectedHello)
                    self.receiveFrame(on: connection)
                case .waiting(let error): self.state = "Waiting: \(error.localizedDescription)"
                case .failed(let error): self.state = "Failed: \(error.localizedDescription)"; self.messageState = "TLS or transport failure"
                case .cancelled: self.state = "Cancelled"
                default: break
                }
            }
        }
        connection.start(queue: .main)
        let timeout = DispatchWorkItem { [weak self, weak connection] in
            Task { @MainActor in
                guard let self, let connection,
                      self.connection === connection,
                      !self.exchangeCompleted else { return }
                connection.cancel()
                self.state = "Failed: connection or message timeout"
                self.messageState = "No verified exchange"
            }
        }
        timeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
    }

    func stop() {
        timeoutWorkItem?.cancel()
        exchangeCompleted = false
        connection?.cancel()
        browser?.cancel()
        connection = nil
        browser = nil
        state = "Cancelled"
        messageState = "No message exchange"
    }

    private func sendFrame(on connection: NWConnection, message: Data) {
        guard let frame = FrameCodec.encode(message) else {
            state = "Failed: invalid frame"
            return
        }
        connection.send(content: frame, completion: .contentProcessed { [weak self, weak connection] error in
            Task { @MainActor in
                guard let self, self.connection === connection, !self.exchangeCompleted else { return }
                self.messageState = error == nil ? "Request sent; awaiting acknowledgment" : "Send failed"
            }
        })
    }

    private func pathDescription(_ path: NWPath?) -> String {
        guard let path else { return "Path unavailable" }
        let interfaces = [
            path.usesInterfaceType(.wifi) ? "wifi" : nil,
            path.usesInterfaceType(.wiredEthernet) ? "wired" : nil,
            path.usesInterfaceType(.cellular) ? "cellular" : nil,
            path.usesInterfaceType(.other) ? "other" : nil
        ].compactMap { $0 }
        return interfaces.isEmpty ? "\(path.status) / interface unknown" : "\(path.status) / \(interfaces.joined(separator: ", "))"
    }

    private func receiveFrame(on connection: NWConnection) {
        var decoder = FrameDecoder()
        func receiveNextChunk() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: FrameDecoder.maximumBufferedBytes) { [weak self, weak connection] data, _, isComplete, error in
                Task { @MainActor in
                    guard let self, let connection, self.connection === connection, !self.exchangeCompleted else { return }
                    if let data, !data.isEmpty {
                        do {
                            for payload in try decoder.append(data) {
                                guard payload == expectedAcknowledgment else {
                                    self.messageState = "Unexpected acknowledgment"
                                    connection.cancel()
                                    return
                                }
                                guard !self.exchangeCompleted else { return }
                                self.exchangeCompleted = true
                                self.timeoutWorkItem?.cancel()
                                self.messageState = "Receipt acknowledgment verified"
                            }
                        } catch {
                            self.messageState = "Invalid or oversized frame"
                            connection.cancel()
                            return
                        }
                    }
                    if let error {
                        self.messageState = "Receipt failed: \(error.localizedDescription)"
                        connection.cancel()
                        return
                    }
                    if isComplete {
                        do { try decoder.finish() }
                        catch { self.messageState = "Truncated acknowledgment" }
                        connection.cancel()
                        return
                    }
                    if !self.exchangeCompleted { receiveNextChunk() }
                }
            }
        }
        receiveNextChunk()
    }
}

@main
struct TransportTLSBrowserApp: App {
    @StateObject private var model = TransportTLSBrowserModel()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("MacDock Transport/TLS Experiment").font(.headline)
                Text("State: \(model.state)").accessibilityIdentifier("transport-state")
                Text("TLS service results: \(model.serviceCount)").accessibilityIdentifier("transport-service-count")
                Text("Path: \(model.pathSummary)").font(.footnote)
                TextField("SHA-256 certificate fingerprint", text: $model.fingerprint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption)
                Text("Message: \(model.messageState)").font(.footnote)
                HStack {
                    Button("Browse") { model.startBrowsing() }
                    Button("Connect") { model.connect() }
                    Button("Stop") { model.stop() }
                }
                Text("TLS encryption is not the same as production pairing.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear { model.startBrowsing() }
        }
    }
}
