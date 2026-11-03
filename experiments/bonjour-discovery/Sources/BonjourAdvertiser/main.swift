import Foundation
import Network

private let serviceType = "_macdock._tcp"
private let serviceName = "MacDock Bonjour Experiment"
private let queue = DispatchQueue(label: "com.macdock.experiment.bonjour-advertiser")

func log(_ message: String) {
    let formatter = ISO8601DateFormatter()
    print("[\(formatter.string(from: Date()))] \(message)")
}

do {
    let listener = try NWListener(
        service: NWListener.Service(name: serviceName, type: serviceType),
        using: .tcp
    )

    listener.stateUpdateHandler = { state in
        switch state {
        case .setup:
            log("listener state: setup")
        case .waiting(let error):
            log("listener state: waiting; error=\(error.localizedDescription)")
        case .ready:
            log("listener state: ready; Bonjour service is being advertised")
        case .failed(let error):
            log("listener state: failed; error=\(error.localizedDescription)")
        case .cancelled:
            log("listener state: cancelled")
        @unknown default:
            log("listener state: unknown")
        }
    }

    listener.newConnectionHandler = { connection in
        log("incoming connection observed; this experiment does not authenticate or exchange data")
        connection.cancel()
    }

    listener.start(queue: queue)
    log("starting advertiser; service type=\(serviceType); service name=\(serviceName)")

    log("type q and press Return to stop advertising")
    while let command = readLine() {
        guard command == "q" || command == "quit" else { continue }
        log("shutdown requested")
        listener.cancel()
        break
    }
    exit(EXIT_SUCCESS)
} catch {
    log("unable to create listener; error=\(error.localizedDescription)")
    exit(EXIT_FAILURE)
}
