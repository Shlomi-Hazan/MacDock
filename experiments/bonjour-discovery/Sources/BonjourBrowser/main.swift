import Foundation
import Network

private let serviceType = "_macdock._tcp"
private let queue = DispatchQueue(label: "com.macdock.experiment.bonjour-browser")

func log(_ message: String) {
    let formatter = ISO8601DateFormatter()
    print("[\(formatter.string(from: Date()))] \(message)")
}

let browser = NWBrowser(
    for: .bonjour(type: serviceType, domain: nil),
    using: .tcp
)

browser.stateUpdateHandler = { state in
    switch state {
    case .setup:
        log("browser state: setup")
    case .ready:
        log("browser state: ready")
    case .waiting(let error):
        log("browser state: waiting; error=\(error.localizedDescription)")
    case .failed(let error):
        log("browser state: failed; error=\(error.localizedDescription)")
    case .cancelled:
        log("browser state: cancelled")
    @unknown default:
        log("browser state: unknown")
    }
}

browser.browseResultsChangedHandler = { results, _ in
    log("browse results changed; visible service count=\(results.count)")
}

log("starting browser; service type=\(serviceType)")
browser.start(queue: queue)
log("type q and press Return to stop browsing")
while let command = readLine() {
    guard command == "q" || command == "quit" else { continue }
    log("shutdown requested")
    browser.cancel()
    break
}
exit(EXIT_SUCCESS)
