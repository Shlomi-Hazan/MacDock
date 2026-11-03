import Network
import SwiftUI

@MainActor
final class BonjourBrowserModel: ObservableObject {
    @Published private(set) var state = "Not started"
    @Published private(set) var visibleServiceCount = 0

    private let serviceType = "_macdock._tcp"
    private var browser: NWBrowser?

    func start() {
        browser?.cancel()
        visibleServiceCount = 0
        state = "Starting browser"

        let browser = NWBrowser(
            for: .bonjour(type: serviceType, domain: nil),
            using: .tcp
        )
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .setup:
                    self.state = "Setup"
                case .ready:
                    self.state = "Ready"
                case .waiting(let error):
                    self.state = "Waiting: \(error.localizedDescription)"
                case .failed(let error):
                    self.state = "Failed: \(error.localizedDescription)"
                case .cancelled:
                    self.state = "Cancelled"
                @unknown default:
                    self.state = "Unknown state"
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.visibleServiceCount = results.count
            }
        }

        browser.start(queue: .main)
    }

    func stop() {
        browser?.cancel()
        browser = nil
        state = "Cancelled"
        visibleServiceCount = 0
    }
}

@main
struct BonjourBrowserApp: App {
    @StateObject private var model = BonjourBrowserModel()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Text("MacDock Bonjour Experiment")
                    .font(.headline)
                Text("State: \(model.state)")
                    .accessibilityIdentifier("browser-state")
                Text("Visible services: \(model.visibleServiceCount)")
                    .accessibilityIdentifier("service-count")
                HStack {
                    Button("Start") { model.start() }
                    Button("Stop") { model.stop() }
                }
                Text("Discovery is not connection or authentication.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .onAppear { model.start() }
        }
    }
}
