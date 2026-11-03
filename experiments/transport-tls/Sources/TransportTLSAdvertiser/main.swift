import Foundation
import Network
import Security
import TransportTLSCore

private let serviceType = "_macdock-tls._tcp"
private let serviceName = "MacDock TLS Experiment"
private let queue = DispatchQueue(label: "com.macdock.experiment.transport-tls-advertiser")
private let expectedClientHello = Data("IPHONE-HELLO/1\n".utf8)
private let acknowledgment = Data("MAC-ACK/1\n".utf8)

final class ExchangeCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func markCompleted() {
        lock.lock()
        completed = true
        lock.unlock()
    }

    var isCompleted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return completed
    }
}

func log(_ message: String) {
    let formatter = ISO8601DateFormatter()
    print("[\(formatter.string(from: Date()))] \(message)")
}

func argumentValue(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name), index + 1 < CommandLine.arguments.count else { return nil }
    return CommandLine.arguments[index + 1]
}

func loadIdentity(p12URL: URL, passwordURL: URL) throws -> sec_identity_t {
    let p12Data = try Data(contentsOf: p12URL)
    let password = try String(contentsOf: passwordURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    var imported: CFArray?
    let status = SecPKCS12Import(
        p12Data as CFData,
        [kSecImportExportPassphrase as String: password] as CFDictionary,
        &imported
    )
    guard status == errSecSuccess,
          let items = imported as? [[String: Any]],
          let identityValue = items.first?[kSecImportItemIdentity as String],
          CFGetTypeID(identityValue as CFTypeRef) == SecIdentityGetTypeID()
    else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to import the PKCS#12 test identity"])
    }
    let identity = identityValue as! SecIdentity
    guard let secIdentity = sec_identity_create(identity) else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecInternalComponent), userInfo: [NSLocalizedDescriptionKey: "Unable to create Network.framework identity"])
    }
    return secIdentity
}

func sendFramedMessage(on connection: NWConnection, message: Data) {
    guard let frame = FrameCodec.encode(message) else {
        log("refusing to send invalid frame")
        connection.cancel()
        return
    }
    connection.send(content: frame, completion: .contentProcessed { error in
        if let error { log("message send failed; error=\(error.localizedDescription)") }
        else { log("acknowledgment sent") }
    })
}

func receiveFramedMessage(on connection: NWConnection, completion: @Sendable @escaping () -> Void) {
    connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { header, _, _, error in
        guard let header, error == nil, let length = FrameCodec.decodeLength(from: header) else {
            log("invalid or incomplete frame header; closing connection")
            connection.cancel()
            return
        }
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { payload, _, _, error in
            guard let payload, error == nil else {
                log("frame payload receive failed; closing connection")
                connection.cancel()
                return
            }
            guard payload == expectedClientHello else {
                log("unexpected message; no application command executed")
                connection.cancel()
                return
            }
            completion()
            log("client hello received; sending receipt acknowledgment")
            sendFramedMessage(on: connection, message: acknowledgment)
        }
    }
}

guard let p12Path = argumentValue("--p12"), let passwordPath = argumentValue("--password-file") else {
    log("usage: TransportTLSAdvertiser --p12 <identity.p12> --password-file <password.txt>")
    exit(EXIT_FAILURE)
}

do {
    let identity = try loadIdentity(p12URL: URL(fileURLWithPath: p12Path), passwordURL: URL(fileURLWithPath: passwordPath))
    let tls = NWProtocolTLS.Options()
    sec_protocol_options_set_local_identity(tls.securityProtocolOptions, identity)
    let parameters = NWParameters(tls: tls, tcp: NWProtocolTCP.Options())
    let listener = try NWListener(service: NWListener.Service(name: serviceName, type: serviceType), using: parameters)

    listener.stateUpdateHandler = { state in
        switch state {
        case .setup: log("listener state: setup")
        case .ready:
            let port = listener.port.map { String($0.rawValue) } ?? "unknown"
            log("listener state: ready; advertising TLS service type=\(serviceType); port=\(port)")
        case .waiting(let error): log("listener state: waiting; error=\(error.localizedDescription)")
        case .failed(let error): log("listener state: failed; error=\(error.localizedDescription)")
        case .cancelled: log("listener state: cancelled")
        @unknown default: log("listener state: unknown")
        }
    }

    listener.newConnectionHandler = { connection in
        log("connection accepted; TLS handshake completes only after connection reaches ready")
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                log("connection state: ready; encrypted channel established")
                let exchange = ExchangeCompletion()
                let timeout = DispatchWorkItem {
                    guard !exchange.isCompleted else { return }
                    log("message exchange timeout; closing connection")
                    connection.cancel()
                }
                queue.asyncAfter(deadline: .now() + 8, execute: timeout)
                receiveFramedMessage(on: connection) { exchange.markCompleted() }
            case .failed(let error): log("connection state: failed; TLS or transport error=\(error.localizedDescription)")
            case .cancelled: log("connection state: cancelled")
            case .waiting(let error): log("connection state: waiting; error=\(error.localizedDescription)")
            default: break
            }
        }
        connection.start(queue: queue)
    }

    listener.start(queue: queue)
    log("starting advertiser; service name=\(serviceName)")
    log("type q and press Return to stop")
    while let command = readLine() {
        guard command == "q" || command == "quit" else { continue }
        listener.cancel()
        break
    }
    exit(EXIT_SUCCESS)
} catch {
    log("unable to start TLS advertiser; error=\(error.localizedDescription)")
    exit(EXIT_FAILURE)
}
