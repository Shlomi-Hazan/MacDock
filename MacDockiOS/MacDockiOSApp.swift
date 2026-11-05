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
    @StateObject private var discovery = BonjourDiscoveryCoordinator()

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

            Text("Discovery: \(discoveryLabel)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if discovery.state.candidates.isEmpty {
                Text("No untrusted Mac candidates visible")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(discovery.state.candidates) { candidate in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.displayName)
                        Text("Untrusted candidate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Retry discovery") { discovery.start() }
                .disabled(scenePhase != .active)
        }
        .padding()
        .task {
            if scenePhase == .active { discovery.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { discovery.start() } else { discovery.stop() }
        }
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

    private var discoveryLabel: String {
        switch discovery.state.phase {
        case .idle: return "Idle"
        case .browsing: return "Starting"
        case .waiting: return "Waiting for local network"
        case .ready: return "Ready"
        case .failed: return "Unavailable"
        case .cancelled: return "Stopped"
        }
    }
}
