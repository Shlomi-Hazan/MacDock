import SwiftUI
import Network
import MacDockShared

final class MacDockBonjourAdvertiser: NSObject, NSApplicationDelegate {
    private var listener: NWListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let listener = try NWListener(using: .tcp)
            listener.service = NWListener.Service(name: "MacDock Mac", type: "_macdock._tcp")
            listener.newConnectionHandler = { connection in connection.cancel() }
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
