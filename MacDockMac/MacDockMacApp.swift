import SwiftUI

@main
struct MacDockMacApp: App {
    var body: some Scene {
        MenuBarExtra("MacDock", systemImage: "dock.rectangle") {
            Text("MacDock Foundation")
                .font(.headline)

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
