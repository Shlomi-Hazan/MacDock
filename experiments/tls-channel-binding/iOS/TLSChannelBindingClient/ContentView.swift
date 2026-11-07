import Foundation
import Network
import OSLog
import Security
import SwiftUI

private let transportLogger = Logger(
    subsystem: "com.macdock.experiment.tls-channel-binding.ios",
    category: "transport"
)

private final class VerificationOutcome: @unchecked Sendable {
    private let lock = NSLock()
    private var rejected = false

    func markRejected() {
        lock.lock()
        rejected = true
        lock.unlock()
    }

    var wasRejected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return rejected
    }
}

/// Installs a verification callback created outside any actor-isolated context.
/// The callback performs only trust evaluation and invokes Network.framework's
/// completion handler on the queue supplied by Network.framework.
private func installScopedTLSVerification(
    on options: NWProtocolTLS.Options,
    anchor: SecCertificate,
    expectedServerName: String,
    callbackQueue: DispatchQueue,
    outcome: VerificationOutcome
) {
    sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, complete in
        transportLogger.info("TLS verification callback invoked")
        let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
        let anchorStatus = SecTrustSetAnchorCertificates(trustReference, [anchor] as CFArray)
        let anchorOnlyStatus = SecTrustSetAnchorCertificatesOnly(trustReference, true)
        let policyStatus = SecTrustSetPolicies(trustReference, SecPolicyCreateSSL(true, expectedServerName as CFString))
        guard anchorStatus == errSecSuccess,
              anchorOnlyStatus == errSecSuccess,
              policyStatus == errSecSuccess else {
            outcome.markRejected()
            transportLogger.error("TLS verification configuration failed: anchor=\(anchorStatus, privacy: .public) anchorOnly=\(anchorOnlyStatus, privacy: .public) policy=\(policyStatus, privacy: .public)")
            complete(false)
            return
        }
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trustReference, &error)
        if !trusted { outcome.markRejected() }
        if let error {
            transportLogger.error("TLS verification failed: domain=\(CFErrorGetDomain(error) as String, privacy: .public) code=\(CFErrorGetCode(error), privacy: .public)")
        } else {
            transportLogger.info("TLS verification callback completed: \(trusted ? "success" : "failure", privacy: .public)")
        }
        complete(trusted)
    }, callbackQueue)
}

@MainActor
final class ChannelBindingClientModel: ObservableObject {
    @Published var host = ""
    @Published var port = "4433"
    @Published var serverName = ""
    @Published var anchorPEM = ""
    @Published private(set) var status = "Idle"
    @Published private(set) var isRunning = false

    private var connection: NWConnection?
    private var localExporter: Data?
    private var verificationOutcome: VerificationOutcome?
    private var timeoutTask: Task<Void, Never>?
    private var attemptGeneration: UInt64 = 0
    private var activeAttempt: UInt64?
    private let queue = DispatchQueue(label: "com.macdock.experiment.tls-channel-binding.ios")
    private let label = "com.macdock.experiment.channel-binding.v1"
    private let context = Data("macdock-channel-binding-context-v1".utf8)

    func start() {
        guard connection == nil else {
            status = "Already running: cancel before starting again"
            return
        }
        guard attemptGeneration < UInt64.max else {
            status = "Failed: transport attempt limit reached"
            return
        }
        attemptGeneration += 1
        let attempt = attemptGeneration
        guard let portNumber = UInt16(port), !host.isEmpty, !serverName.isEmpty,
              let anchor = makeCertificate(from: anchorPEM) else {
            status = "Configuration incomplete: host, port, server name, and public anchor are required"
            return
        }

        activeAttempt = attempt
        isRunning = true
        status = "Connecting (unverified candidate)"
        transportLogger.info("starting transport attempt generation: \(attempt, privacy: .public)")
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        let expectedServerName = serverName
        let verificationOutcome = VerificationOutcome()
        self.verificationOutcome = verificationOutcome
        serverName.withCString { name in
            sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, name)
        }
        installScopedTLSVerification(
            on: options,
            anchor: anchor,
            expectedServerName: expectedServerName,
            callbackQueue: queue,
            outcome: verificationOutcome
        )

        let nwPort = NWEndpoint.Port(rawValue: portNumber)!
        let newConnection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: NWParameters(tls: options, tcp: NWProtocolTCP.Options()))
        connection = newConnection
        newConnection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self, self.activeAttempt == attempt, self.connection === newConnection else { return }
                transportLogger.info("connection state generation=\(attempt, privacy: .public): \(String(describing: state), privacy: .public)")
                switch state {
                case .preparing:
                    self.status = "TLS preparing"
                case .ready:
                    self.status = "TLS ready; deriving channel binding"
                    if self.localExporter == nil {
                        self.deriveAndRequestResponse(on: newConnection, attempt: attempt)
                    }
                case .waiting(let error):
                    self.status = "Waiting: \(error)"
                case .failed(let error):
                    transportLogger.error("TLS/transport failure: \(String(describing: error), privacy: .public)")
                    let status = verificationOutcome.wasRejected
                        ? "Failed: certificate verification rejected"
                        : "TLS/transport failed: \(error)"
                    self.finish(attempt: attempt, status: status, cancelConnection: false)
                case .cancelled:
                    self.finish(attempt: attempt, status: "Transport closed before verified exchange", cancelConnection: false)
                default:
                    break
                }
            }
        }
        newConnection.start(queue: queue)
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.handleTimeout(attempt: attempt)
        }
    }

    func cancel() {
        guard let attempt = activeAttempt else {
            if status != "Idle" { status = "Cancelled" }
            return
        }
        transportLogger.info("user cancelled transport attempt")
        finish(attempt: attempt, status: "Cancelled", cancelConnection: true)
    }

    private func handleTimeout(attempt: UInt64) {
        guard activeAttempt == attempt else { return }
        transportLogger.error("transport timeout")
        let status = verificationOutcome?.wasRejected == true
            ? "Failed: certificate verification rejected"
            : "Timeout: no verified exchange"
        finish(attempt: attempt, status: status, cancelConnection: true)
    }

    private func finish(attempt: UInt64, status terminalStatus: String, cancelConnection: Bool) {
        guard activeAttempt == attempt else { return }
        timeoutTask?.cancel()
        timeoutTask = nil
        activeAttempt = nil
        isRunning = false
        let currentConnection = connection
        connection = nil
        localExporter = nil
        verificationOutcome = nil
        self.status = terminalStatus
        if cancelConnection { currentConnection?.cancel() }
    }

    private func deriveAndRequestResponse(on connection: NWConnection, attempt: UInt64) {
        guard let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata,
              let exporter = deriveExporter(from: metadata) else {
            finish(attempt: attempt, status: "Failed: TLS metadata unavailable", cancelConnection: true)
            return
        }
        localExporter = exporter
        connection.send(content: Data("MDCB".utf8), completion: .contentProcessed { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    guard let self, self.activeAttempt == attempt else { return }
                    transportLogger.error("diagnostic request send failed: \(String(describing: error), privacy: .public)")
                    self.finish(attempt: attempt, status: "Failed: diagnostic request not sent: \(error)", cancelConnection: true)
                }
                return
            }
            connection.receive(minimumIncompleteLength: 32, maximumLength: 32) { data, _, _, error in
                DispatchQueue.main.async {
                    guard let self, self.activeAttempt == attempt, self.connection === connection else { return }
                    guard error == nil, let data, data.count == 32, let localExporter = self.localExporter else {
                        transportLogger.error("diagnostic response missing or invalid: \(String(describing: error), privacy: .public)")
                        self.finish(attempt: attempt, status: "Failed: no verified exporter response", cancelConnection: true)
                        return
                    }
                    if data == localExporter {
                        self.finish(attempt: attempt, status: "Diagnostic exchange complete (unverified)", cancelConnection: true)
                    } else {
                        self.finish(attempt: attempt, status: "Failed: exporter mismatch", cancelConnection: true)
                    }
                }
            }
        })
    }

    private func deriveExporter(from metadata: NWProtocolTLS.Metadata) -> Data? {
        label.withCString { labelPointer in
            context.withUnsafeBytes { bytes in
                guard let contextPointer = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let exported = sec_protocol_metadata_create_secret_with_context(
                          metadata.securityProtocolMetadata,
                          label.utf8.count,
                          labelPointer,
                          context.count,
                          contextPointer,
                          32
                      ) else { return nil }
                return Data(unsafeBitCast(exported, to: DispatchData.self))
            }
        }
    }

    private func makeCertificate(from pem: String) -> SecCertificate? {
        let body = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        guard let data = Data(base64Encoded: body) else { return nil }
        return SecCertificateCreateWithData(nil, data as CFData)
    }
}

struct ContentView: View {
    @StateObject private var model = ChannelBindingClientModel()

    var body: some View {
        Form {
            Section("Temporary TLS test configuration") {
                TextField("Mac host or IP", text: $model.host)
                    .textInputAutocapitalization(.never)
                TextField("Port", text: $model.port)
                    .keyboardType(.numberPad)
                TextField("TLS server name", text: $model.serverName)
                    .textInputAutocapitalization(.never)
                TextEditor(text: $model.anchorPEM)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if model.anchorPEM.isEmpty { Text("Paste the public test certificate PEM") .foregroundStyle(.secondary) }
                    }
            }
            Section("Status") {
                Text(model.status)
                Text("Exporter bytes are never displayed or persisted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Actions") {
                Button("Start experiment", action: model.start)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isRunning)
                    .accessibilityIdentifier("start-experiment")
            }
            Section {
                Button("Cancel", role: .cancel, action: model.cancel)
                    .buttonStyle(.bordered)
                    .disabled(!model.isRunning)
                    .accessibilityIdentifier("cancel-experiment")
            }
        }
        .navigationTitle("TLS Channel Binding")
    }
}
