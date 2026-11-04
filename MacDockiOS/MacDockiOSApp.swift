import SwiftUI

@main
struct MacDockiOSApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "dock.rectangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("MacDock")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Foreground foundation shell")
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
