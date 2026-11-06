import Dispatch
import Foundation
import Network
import Security

private let queue = DispatchQueue(label: "com.macdock.experiment.tls-channel-binding")
private let label = "com.macdock.experiment.channel-binding.v1"
private let context = Data("macdock-channel-binding-context-v1".utf8)
private let alternateLabel = "com.macdock.experiment.channel-binding.alternate"
private let alternateContext = Data("macdock-channel-binding-context-alternate".utf8)
private let exportLength = 32

/// Compile and runtime harness for public TLS metadata APIs.
/// It never creates an identity or trust record and accepts only explicit test files.
@available(macOS 14, iOS 17, *)
enum TLSChannelBindingProbe {
    static func deriveExporterLikeValue(
        from metadata: NWProtocolTLS.Metadata,
        usingLabel requestedLabel: String = label,
        context requestedContext: Data = context
    ) -> Data? {
        let protocolMetadata = metadata.securityProtocolMetadata
        let result: Data? = requestedLabel.withCString { labelPointer in
            requestedContext.withUnsafeBytes { (contextBytes: UnsafeRawBufferPointer) -> Data? in
                guard let contextPointer = contextBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let exported = sec_protocol_metadata_create_secret_with_context(
                          protocolMetadata,
                          requestedLabel.utf8.count,
                          labelPointer,
                          requestedContext.count,
                          contextPointer,
                          exportLength
                      ) else {
                    return nil
                }
                let dispatchData = unsafeBitCast(exported, to: DispatchData.self)
                let bytes = Data(dispatchData)
                return bytes.count == exportLength ? bytes : nil
            }
        }
        return result
    }

    static func makeTLSOptions(identity: sec_identity_t? = nil, requirePeerAuthentication: Bool = true) -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, requirePeerAuthentication)
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(options.securityProtocolOptions, .TLSv13)
        if let identity {
            sec_protocol_options_set_local_identity(options.securityProtocolOptions, identity)
        }
        return options
    }
}

private struct TestIdentity { let value: sec_identity_t }

private struct ExchangeValues {
    let client: Data
    let server: Data
    let alternateLabel: Data
    let alternateContext: Data
}

private final class ExchangeState: @unchecked Sendable {
    private let lock = NSLock()
    private var clientValue: Data?
    private var serverValue: Data?
    private var clientAlternateLabel: Data?
    private var clientAlternateContext: Data?

    func recordClient(_ value: Data, alternateLabel: Data, alternateContext: Data) {
        lock.lock(); defer { lock.unlock() }
        clientValue = value
        clientAlternateLabel = alternateLabel
        clientAlternateContext = alternateContext
    }

    func recordServer(_ value: Data) {
        lock.lock(); defer { lock.unlock() }
        serverValue = value
    }

    func snapshot() -> ExchangeValues? {
        lock.lock(); defer { lock.unlock() }
        guard let clientValue, let serverValue, let clientAlternateLabel, let clientAlternateContext else { return nil }
        return ExchangeValues(client: clientValue, server: serverValue, alternateLabel: clientAlternateLabel, alternateContext: clientAlternateContext)
    }
}

private final class ConnectionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: NWConnection?

    var value: NWConnection? {
        get {
            lock.lock(); defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock(); defer { lock.unlock() }
            storedValue = newValue
        }
    }
}

private final class ListenerSession: @unchecked Sendable {
    private let lock = NSLock()
    private let connection: NWConnection
    private let finished: DispatchSemaphore
    private var exchangeStarted = false
    private var didFinish = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var responseWorkItem: DispatchWorkItem?

    init(connection: NWConnection, finished: DispatchSemaphore) {
        self.connection = connection
        self.finished = finished
    }

    func beginExchange() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !didFinish, !exchangeStarted else { return false }
        exchangeStarted = true
        return true
    }

    func scheduleTimeout(on queue: DispatchQueue, after delay: TimeInterval) {
        let workItem = DispatchWorkItem { [weak self] in
            self?.finish(reason: "server diagnostic exchange timeout")
        }
        lock.lock()
        timeoutWorkItem = workItem
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func finish(reason: String) {
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        didFinish = true
        timeoutWorkItem?.cancel()
        responseWorkItem?.cancel()
        lock.unlock()
        print(reason)
        connection.cancel()
        finished.signal()
    }

    func scheduleResponse(on queue: DispatchQueue, after delay: TimeInterval, connection: NWConnection, exporter: Data) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let shouldRun = !self.didFinish
            self.lock.unlock()
            guard shouldRun else { return }
            connection.send(content: exporter, completion: .contentProcessed { error in
                if let error {
                    print("server exporter response failure: \(error)")
                } else {
                    print("server exporter response send completed locally; remote receipt unverified")
                }
                self.finish(reason: error == nil
                    ? "server diagnostic response send completed locally; remote receipt unverified"
                    : "server diagnostic exchange failed")
            })
        }
        lock.lock()
        guard !didFinish else {
            lock.unlock()
            return
        }
        responseWorkItem = workItem
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func handleTransportState(_ state: NWConnection.State) {
        switch state {
        case .failed(let error):
            finish(reason: "server connection failed before diagnostic completion: \(error)")
        case .cancelled:
            finish(reason: "server connection cancelled before diagnostic completion")
        default:
            break
        }
    }
}

private final class ListenerSessionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: ListenerSession?

    var value: ListenerSession? {
        get {
            lock.lock(); defer { lock.unlock() }
            return storedValue
        }
        set {
            lock.lock(); defer { lock.unlock() }
            storedValue = newValue
        }
    }
}

private final class VerificationDiagnostics: @unchecked Sendable {
    private let lock = NSLock()
    private var callbackCount = 0

    func recordCallback() {
        lock.lock(); defer { lock.unlock() }
        callbackCount += 1
    }

    var wasInvoked: Bool {
        lock.lock(); defer { lock.unlock() }
        return callbackCount > 0
    }
}

private func loadIdentity(p12URL: URL, passwordURL: URL) throws -> TestIdentity {
    let p12Data = try Data(contentsOf: p12URL)
    let password = try String(contentsOf: passwordURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    var imported: CFArray?
    let status = SecPKCS12Import(p12Data as CFData, [kSecImportExportPassphrase as String: password] as CFDictionary, &imported)
    guard status == errSecSuccess,
          let items = imported as? [[String: Any]],
          let identityValue = items.first?[kSecImportItemIdentity as String],
          CFGetTypeID(identityValue as CFTypeRef) == SecIdentityGetTypeID() else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to import the temporary test identity"])
    }
    let identity = identityValue as! SecIdentity
    var privateKey: SecKey?
    let privateKeyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)
    print("identity private-key lookup status: \(privateKeyStatus)")
    if let privateKey {
        let signingSupported = SecKeyIsAlgorithmSupported(privateKey, .sign, .rsaSignatureMessagePKCS1v15SHA256)
        print("identity private-key signing capability: \(signingSupported ? "available" : "not reported")")
    }
    guard let value = sec_identity_create(identity) else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalComponent), userInfo: [NSLocalizedDescriptionKey: "Unable to create the Network.framework identity"])
    }
    return TestIdentity(value: value)
}

private func loadCertificate(url: URL) throws -> SecCertificate {
    let data = try Data(contentsOf: url)
    guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecDecode), userInfo: [NSLocalizedDescriptionKey: "Unable to load the temporary DER trust anchor"])
    }
    return certificate
}

private func configureScopedVerification(
    options: NWProtocolTLS.Options,
    anchor: SecCertificate,
    diagnostics: VerificationDiagnostics
) {
    sec_protocol_options_set_verify_block(options.securityProtocolOptions, { _, trust, complete in
        diagnostics.recordCallback()
        print("TLS verification callback: invoked")
        let trustReference = sec_trust_copy_ref(trust).takeRetainedValue()
        let anchorStatus = SecTrustSetAnchorCertificates(trustReference, [anchor] as CFArray)
        let anchorOnlyStatus = SecTrustSetAnchorCertificatesOnly(trustReference, true)
        let policyStatus = SecTrustSetPolicies(trustReference, SecPolicyCreateSSL(true, "localhost" as CFString))
        guard anchorStatus == errSecSuccess,
              anchorOnlyStatus == errSecSuccess,
              policyStatus == errSecSuccess else {
            print("TLS verification result: configuration failure; anchorStatus=\(anchorStatus); anchorOnlyStatus=\(anchorOnlyStatus); policyStatus=\(policyStatus)")
            complete(false)
            return
        }
        var error: CFError?
        let trusted = SecTrustEvaluateWithError(trustReference, &error)
        if let error {
            print("TLS verification result: failure; anchorStatus=\(anchorStatus); anchorOnlyStatus=\(anchorOnlyStatus); policyStatus=\(policyStatus); error=\(String(describing: CFErrorGetDomain(error))):\(CFErrorGetCode(error))")
        } else {
            print("TLS verification result: \(trusted ? "success" : "failure"); anchorStatus=\(anchorStatus); anchorOnlyStatus=\(anchorOnlyStatus); policyStatus=\(policyStatus)")
        }
        complete(trusted)
    }, queue)
}

private func metadata(for connection: NWConnection) -> NWProtocolTLS.Metadata? {
    connection.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata
}

private func runExchange(identity: TestIdentity, anchor: SecCertificate) throws -> ExchangeValues? {
    let serverTLS = TLSChannelBindingProbe.makeTLSOptions(identity: identity.value, requirePeerAuthentication: false)
    let listener = try NWListener(using: NWParameters(tls: serverTLS, tcp: NWProtocolTCP.Options()))
    let state = ExchangeState()
    let verificationDiagnostics = VerificationDiagnostics()
    let completed = DispatchSemaphore(value: 0)
    let acceptedConnection = ConnectionBox()
    let clientConnection = ConnectionBox()

    listener.newConnectionHandler = { connection in
        print("listener accepted connection")
        acceptedConnection.value = connection
        connection.stateUpdateHandler = { connectionState in
            print("server connection state: \(connectionState)")
            if case .waiting(let error) = connectionState {
                print("server connection waiting error: \(error)")
            } else if case .failed(let error) = connectionState {
                print("server connection failure: \(error)")
            } else if case .cancelled = connectionState {
                print("server connection cancelled")
            }
            guard case .ready = connectionState,
                  let tlsMetadata = metadata(for: connection),
                  let value = TLSChannelBindingProbe.deriveExporterLikeValue(from: tlsMetadata) else { return }
            state.recordServer(value)
            if state.snapshot() != nil { completed.signal() }
        }
        connection.start(queue: queue)
    }

    listener.stateUpdateHandler = { listenerState in
        print("listener state: \(listenerState)")
        guard case .ready = listenerState, let port = listener.port else { return }
        let clientTLS = TLSChannelBindingProbe.makeTLSOptions()
        configureScopedVerification(options: clientTLS, anchor: anchor, diagnostics: verificationDiagnostics)
        "localhost".withCString { name in
            sec_protocol_options_set_tls_server_name(clientTLS.securityProtocolOptions, name)
        }
        let connection = NWConnection(host: "127.0.0.1", port: port, using: NWParameters(tls: clientTLS, tcp: NWProtocolTCP.Options()))
        clientConnection.value = connection
        connection.stateUpdateHandler = { connectionState in
            print("client connection state: \(connectionState)")
            if case .waiting(let error) = connectionState {
                print("client connection waiting error: \(error)")
            } else if case .failed(let error) = connectionState {
                print("client connection failure: \(error)")
            } else if case .cancelled = connectionState {
                print("client connection cancelled")
            }
            guard case .ready = connectionState,
                  let tlsMetadata = metadata(for: connection),
                  let value = TLSChannelBindingProbe.deriveExporterLikeValue(from: tlsMetadata),
                  let alternateLabelValue = TLSChannelBindingProbe.deriveExporterLikeValue(from: tlsMetadata, usingLabel: alternateLabel),
                  let alternateContextValue = TLSChannelBindingProbe.deriveExporterLikeValue(from: tlsMetadata, context: alternateContext) else { return }
            state.recordClient(value, alternateLabel: alternateLabelValue, alternateContext: alternateContextValue)
            if state.snapshot() != nil { completed.signal() }
        }
        connection.start(queue: queue)
    }

    listener.start(queue: queue)
    defer {
        clientConnection.value?.cancel()
        acceptedConnection.value?.cancel()
        listener.cancel()
    }

    guard completed.wait(timeout: .now() + 8) == .success else {
        print("runtime timeout phase: TLS ready/exporter completion; verification callback invoked=\(verificationDiagnostics.wasInvoked ? "yes" : "no")")
        return nil
    }
    return state.snapshot()
}

private func argument(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

private func runListener(identity: TestIdentity, port: UInt16, duration: TimeInterval, diagnosticDelay: TimeInterval) throws {
    let serverTLS = TLSChannelBindingProbe.makeTLSOptions(identity: identity.value, requirePeerAuthentication: false)
    let parameters = NWParameters(tls: serverTLS, tcp: NWProtocolTCP.Options())
    let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
    let finished = DispatchSemaphore(value: 0)
    let accepted = ConnectionBox()
    let sessionBox = ListenerSessionBox()

    listener.stateUpdateHandler = { state in
        print("listener state: \(state)")
        if case .failed(let error) = state {
            print("listener failure: \(error)")
            finished.signal()
        }
    }
    listener.newConnectionHandler = { connection in
        accepted.value = connection
        let acceptedSession = ListenerSession(connection: connection, finished: finished)
        sessionBox.value = acceptedSession
        print("listener accepted connection")
        connection.stateUpdateHandler = { state in
            print("server connection state: \(state)")
            acceptedSession.handleTransportState(state)
            guard case .ready = state else { return }
            guard acceptedSession.beginExchange() else { return }
            print("server TLS ready; retrieving connection metadata")
            guard let metadata = metadata(for: connection),
                  let exporter = TLSChannelBindingProbe.deriveExporterLikeValue(from: metadata) else {
                acceptedSession.finish(reason: "server TLS metadata unavailable after ready")
                return
            }
            print("server TLS metadata ready; diagnostic receive started")
            acceptedSession.scheduleTimeout(on: queue, after: 10)
            let hello = Data("MDCB".utf8)
            connection.receive(minimumIncompleteLength: hello.count, maximumLength: hello.count) { data, _, _, error in
                guard error == nil, data == hello else {
                    print("server diagnostic request rejected")
                    acceptedSession.finish(reason: "server diagnostic request rejected")
                    return
                }
                if diagnosticDelay > 0 {
                    print("server diagnostic response delayed: \(diagnosticDelay)s")
                }
                acceptedSession.scheduleResponse(on: queue, after: diagnosticDelay, connection: connection, exporter: exporter)
            }
        }
        connection.start(queue: queue)
    }
    listener.start(queue: queue)
    if case .success = finished.wait(timeout: .now() + duration) {
        sessionBox.value?.finish(reason: "listener session finished")
    } else {
        print("listener timeout: no completed diagnostic exchange")
        sessionBox.value?.finish(reason: "listener duration expired")
    }
    listener.cancel()
}

@main
struct Main {
    static func main() {
        if !CommandLine.arguments.contains("--runtime") {
            print("TLS channel-binding API probe compiled; no network connection was opened.")
            print("Public APIs referenced: NWProtocolTLS.Metadata, sec_protocol_metadata_create_secret_with_context, peer public-key and certificate-chain access.")
            print("TLS verification remains required; no trust callback or identity material is configured.")
            return
        }

        guard let p12 = argument("--p12"), let password = argument("--password-file"), let ca = argument("--ca-cert") else {
            print("usage: TLSChannelBindingProbe --runtime --p12 <identity.p12> --password-file <password.txt> --ca-cert <anchor.der>")
            exit(EXIT_FAILURE)
        }

        do {
            let identity = try loadIdentity(p12URL: URL(fileURLWithPath: p12), passwordURL: URL(fileURLWithPath: password))
            let anchor = try loadCertificate(url: URL(fileURLWithPath: ca))
            if CommandLine.arguments.contains("--listen") {
                let port = UInt16(argument("--port") ?? "4433") ?? 4433
                let duration = TimeInterval(argument("--duration") ?? "120") ?? 120
                let requestedDelay = TimeInterval(argument("--diagnostic-delay") ?? "0") ?? 0
                let diagnosticDelay = min(max(requestedDelay, 0), 30)
                try runListener(identity: identity, port: port, duration: duration, diagnosticDelay: diagnosticDelay)
                return
            }
            guard let first = try runExchange(identity: identity, anchor: anchor),
                  let second = try runExchange(identity: identity, anchor: anchor) else {
                print("runtime exchange failed: no verified exporter result")
                exit(EXIT_FAILURE)
            }

            print("TLS 1.3 local handshake: succeeded")
            print("same-session exporter equality: \(first.client == first.server ? "equal" : "mismatch")")
            print("different-session exporter inequality: \(first.client != second.client ? "different" : "equal")")
            print("different-label isolation: \(first.client != first.alternateLabel ? "different" : "equal")")
            print("different-context isolation: \(first.client != first.alternateContext ? "different" : "equal")")
            print("peer identity: certificate verified against explicit process-scoped DER anchor")
            print("authorization: not established")
        } catch {
            print("runtime experiment failed closed: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        }
    }
}
