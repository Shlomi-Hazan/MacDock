import SwiftUI
import MacDockShared

@main
struct MacDockiOSApp: App {
    var body: some Scene {
        WindowGroup {
            MacDockiOSRootView()
        }
    }
}

private struct MacDockiOSRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("MacDock")
                .font(.title)
                .fontWeight(.semibold)

            Text(MacDockFoundationInfo.current.stageLabel)
                .foregroundStyle(.secondary)

            Text("Foreground foundation shell")
                .foregroundStyle(.secondary)

            Text("Lifecycle: \(lifecycleLabel)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Application lifecycle: \(lifecycleLabel)")
        }
        .padding()
    }

    private var lifecycleLabel: String {
        switch scenePhase {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case .background:
            return "Background"
        @unknown default:
            return "Unknown"
        }
    }
}
