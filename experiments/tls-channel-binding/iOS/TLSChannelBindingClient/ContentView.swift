import Foundation
import Network
import Security
import SwiftUI

@MainActor
final class ChannelBindingClientModel: ObservableObject {
    @Published var host = ""
    @Published var port = "4433"
    @Published var serverName = ""
    @Published var anchorPEM = ""
    @Published private(set) var status = "Idle"

    private var connection: NWConnection?
    private var localExporter: Data?
    private var timeoutTask: Task<Void, Never>?
    private let queue = DispatchQueue(label: "com.macdock.experiment.tls-channel-binding.ios")
    private let label = "com.macdock.experiment.channel-binding.v1"
    private let context = Data("macdock-channel-binding-context-v1".utf8)

    func start() {
        cancel()
        guard let portNumber = UInt16(port), !host.isEmpty, !serverName.isEmpty,
              let anchor = makeCertificate(from: anchorPEM) else {
            status = "Configuration incomplete: host, port, server name, and public anchor are required"
            return
        }

        status = "Connecting (unverified candidate)"
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        let expectedServerName = serverName
        serverName.withCString { name in
            sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, name)
        }
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { [weak self] _, trust, complete in
            let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
            SecTrustSetAnchorCertificates(trustReference, [anchor] as CFArray)
            SecTrustSetAnchorCertificatesOnly(trustReference, true)
            SecTrustSetPolicies(trustReference, SecPolicyCreateSSL(true, expectedServerName as CFString))
            var error: CFError?
            let trusted = SecTrustEvaluateWithError(trustReference, &error)
            DispatchQueue.main.async {
                self?.status = trusted ? "TLS certificate verified" : "TLS certificate rejected"
            }
            complete(trusted)
        }, queue)

        let nwPort = NWEndpoint.Port(rawValue: portNumber)!
        let newConnection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: NWParameters(tls: options, tcp: NWProtocolTCP.Options()))
        connection = newConnection
        newConnection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .preparing:
                    self?.status = "TLS preparing"
                case .ready:
                    self?.status = "TLS ready; deriving channel binding"
                    self?.deriveAndRequestResponse(on: newConnection)
                case .waiting(let error):
                    self?.status = "Waiting: (error)"
                case .failed(let error):
                    self?.status = "TLS/transport failed: (error)"
                case .cancelled:
                    if self?.status != "Diagnostic exchange complete" {
                        self?.status = "Cancelled"
                    }
                default:
                    break
                }
            }
        }
        newConnection.start(queue: queue)
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            self?.status = "Timeout: no verified exchange"
            self?.connection?.cancel()
        }
    }

    func cancel() {
        timeoutTask?.cancel()
        timeoutTask = nil
        connection?.cancel()
        connection = nil
        localExporter = nil
        if status != "Idle" { status = "Cancelled" }
    }

    private func deriveAndRequestResponse(on connection: NWConnection) {
        guard let metadata = connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata,
              let exporter = deriveExporter(from: metadata) else {
            status = "Failed: TLS metadata unavailable"
            connection.cancel()
            return
        }
        localExporter = exporter
        connection.send(content: Data("MDCB".utf8), completion: .contentProcessed { [weak self] error in
            if let error {
                DispatchQueue.main.async { self?.status = "Failed: diagnostic request not sent ((error))" }
                return
            }
            connection.receive(minimumIncompleteLength: 32, maximumLength: 32) { data, _, _, error in
                DispatchQueue.main.async {
                    guard error == nil, let data, let localExporter = self?.localExporter else {
                        self?.status = "Failed: no verified exporter response"
                        return
                    }
                    self?.status = data == localExporter ? "Diagnostic exchange complete (unverified)" : "Failed: exporter mismatch"
                    connection.cancel()
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
            HStack {
                Button("Start experiment", action: model.start)
                Button("Cancel", role: .cancel, action: model.cancel)
            }
        }
        .navigationTitle("TLS Channel Binding")
    }
}
