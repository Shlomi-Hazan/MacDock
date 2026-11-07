import CryptoKit
import Foundation
import MTLSPeerPinningCore
import Network
import Security

private let queue = DispatchQueue(label: "com.macdock.experiment.mtls-peer-pinning")

struct Arguments {
    let serverP12: URL
    let serverPassword: URL
    let serverAnchor: URL
    let serverPin: String
    let clientP12: URL
    let clientPassword: URL
    let clientAnchor: URL
    let clientPin: String
}

enum ProbeError: Error, LocalizedError {
    case missingArgument(String)
    case invalidFixture(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingArgument(let value): return "missing argument \(value)"
        case .invalidFixture(let value): return "invalid test fixture: \(value)"
        case .timeout: return "probe timed out"
        }
    }
}

final class ProbeState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedConnection: NWConnection?
    private var serverReady = false
    private var clientReady = false

    func recordConnection(_ connection: NWConnection) {
        lock.lock(); defer { lock.unlock() }
        storedConnection = connection
    }

    func recordServerReady() {
        lock.lock(); defer { lock.unlock() }
        serverReady = true
    }

    func recordClientReady() {
        lock.lock(); defer { lock.unlock() }
        clientReady = true
    }

    func snapshot() -> (connection: NWConnection?, serverReady: Bool, clientReady: Bool) {
        lock.lock(); defer { lock.unlock() }
        return (storedConnection, serverReady, clientReady)
    }
}

func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

func requiredURL(_ name: String) throws -> URL {
    guard let value = argument(name) else { throw ProbeError.missingArgument(name) }
    return URL(fileURLWithPath: value)
}

func normalizedFingerprint(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

func certificateFingerprint(_ certificate: SecCertificate) -> String {
    let data = SecCertificateCopyData(certificate) as Data
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func loadCertificate(_ url: URL) throws -> SecCertificate {
    let data = try Data(contentsOf: url)
    guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
        throw ProbeError.invalidFixture("certificate \(url.lastPathComponent)")
    }
    return certificate
}

func loadIdentity(p12: URL, passwordFile: URL) throws -> sec_identity_t {
    let data = try Data(contentsOf: p12)
    let password = try String(contentsOf: passwordFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    var imported: CFArray?
    let status = SecPKCS12Import(data as CFData, [kSecImportExportPassphrase as String: password] as CFDictionary, &imported)
    guard status == errSecSuccess,
          let items = imported as? [[String: Any]],
          let value = items.first?[kSecImportItemIdentity as String],
          CFGetTypeID(value as CFTypeRef) == SecIdentityGetTypeID(),
          let identity = sec_identity_create(value as! SecIdentity) else {
        throw ProbeError.invalidFixture("PKCS#12 \(p12.lastPathComponent), status=\(status)")
    }
    return identity
}

func configureVerification(
    options: NWProtocolTLS.Options,
    anchor: SecCertificate,
    expectedFingerprint: String,
    serverName: String?,
    label: String
) {
    sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, complete in
        let trustRef = sec_trust_copy_ref(trust).takeRetainedValue()
        let anchorStatus = SecTrustSetAnchorCertificates(trustRef, [anchor] as CFArray)
        let anchorOnlyStatus = SecTrustSetAnchorCertificatesOnly(trustRef, true)
        let policy = SecPolicyCreateSSL(serverName != nil, serverName as CFString?)
        let policyStatus = SecTrustSetPolicies(trustRef, policy)
        let certificateChain = SecTrustCopyCertificateChain(trustRef) as? [SecCertificate]
        guard anchorStatus == errSecSuccess, anchorOnlyStatus == errSecSuccess, policyStatus == errSecSuccess,
              let leaf = certificateChain?.first else {
            print("\(label) verification: configuration or certificate failure")
            complete(false)
            return
        }
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trustRef, &error)
        let fingerprint = certificateFingerprint(leaf)
        let pinMatches = fingerprint == expectedFingerprint
        print("\(label) verification: trust=\(trusted) pin=\(pinMatches)")
        complete(trusted && pinMatches)
    }, queue)
}

func tlsOptions(identity: sec_identity_t, anchor: SecCertificate, pin: String, serverName: String?, label: String) -> NWProtocolTLS.Options {
    let options = NWProtocolTLS.Options()
    sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
    sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
    sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
    sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)
    configureVerification(options: options, anchor: anchor, expectedFingerprint: pin, serverName: serverName, label: label)
    return options
}

func parseArguments() throws -> Arguments {
    let serverP12 = try requiredURL("--server-p12")
    let serverPassword = try requiredURL("--server-password-file")
    let serverAnchor = try requiredURL("--server-anchor")
    let serverPin = normalizedFingerprint(try String(contentsOf: requiredURL("--server-pin-file"), encoding: .utf8))
    let clientP12 = try requiredURL("--client-p12")
    let clientPassword = try requiredURL("--client-password-file")
    let clientAnchor = try requiredURL("--client-anchor")
    let clientPin = normalizedFingerprint(try String(contentsOf: requiredURL("--client-pin-file"), encoding: .utf8))
    guard serverPin.count == 64, clientPin.count == 64 else { throw ProbeError.invalidFixture("fingerprint length") }
    return Arguments(serverP12: serverP12, serverPassword: serverPassword, serverAnchor: serverAnchor, serverPin: serverPin, clientP12: clientP12, clientPassword: clientPassword, clientAnchor: clientAnchor, clientPin: clientPin)
}

let result: Int32
do {
    let args = try parseArguments()
    let serverIdentity = try loadIdentity(p12: args.serverP12, passwordFile: args.serverPassword)
    let clientIdentity = try loadIdentity(p12: args.clientP12, passwordFile: args.clientPassword)
    let serverAnchor = try loadCertificate(args.serverAnchor)
    let clientAnchor = try loadCertificate(args.clientAnchor)
    let serverTLS = tlsOptions(identity: serverIdentity, anchor: clientAnchor, pin: args.clientPin, serverName: nil, label: "server/client verification")
    let listener = try NWListener(using: NWParameters(tls: serverTLS, tcp: NWProtocolTCP.Options()))
    let finished = DispatchSemaphore(value: 0)
    let serverReady = DispatchSemaphore(value: 0)
    let stateBox = ProbeState()

    listener.newConnectionHandler = { connection in
        print("server accepted connection")
        stateBox.recordConnection(connection)
        connection.stateUpdateHandler = { state in
            print("server connection state: \(state)")
            if case .ready = state {
                stateBox.recordServerReady()
                finished.signal()
            }
        }
        connection.start(queue: queue)
    }
    listener.stateUpdateHandler = { state in
        print("listener state: \(state)")
        if case .ready = state {
            serverReady.signal()
        }
    }
    listener.start(queue: queue)
    guard serverReady.wait(timeout: .now() + 5) == .success, let port = listener.port else { throw ProbeError.timeout }
    let clientTLS = tlsOptions(identity: clientIdentity, anchor: serverAnchor, pin: args.serverPin, serverName: "localhost", label: "client/server verification")
    let client = NWConnection(host: "127.0.0.1", port: port, using: NWParameters(tls: clientTLS, tcp: NWProtocolTCP.Options()))
    client.stateUpdateHandler = { state in
        print("client connection state: \(state)")
        if case .ready = state {
            stateBox.recordClientReady()
            finished.signal()
        }
    }
    client.start(queue: queue)
    guard finished.wait(timeout: .now() + 8) == .success, finished.wait(timeout: .now() + 8) == .success else {
        throw ProbeError.timeout
    }
    let snapshot = stateBox.snapshot()
    print("mTLS result: server_tls_ready=\(snapshot.serverReady) client_tls_ready=\(snapshot.clientReady) peer_pins=accepted")
    client.cancel(); snapshot.connection?.cancel(); listener.cancel()
    result = (snapshot.serverReady && snapshot.clientReady) ? EXIT_SUCCESS : EXIT_FAILURE
} catch {
    print("mTLS experiment failed closed: \(error.localizedDescription)")
    result = EXIT_FAILURE
}
exit(result)
