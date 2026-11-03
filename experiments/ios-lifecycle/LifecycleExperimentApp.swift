import SwiftUI
import UIKit

@MainActor
final class LifecycleExperimentModel: ObservableObject {
    @Published private(set) var lifecycleState: LifecycleState = .unknown
    @Published private(set) var userKeepAwake = false
    @Published private(set) var appliedIdleTimerDisabled = false
    @Published private(set) var events: [String] = []

    private var state = KeepAwakeStateModel()

    func setKeepAwake(_ enabled: Bool) {
        state.setUserEnabled(enabled)
        userKeepAwake = state.userEnabled
        reconcileSystemIdleTimer(reason: enabled ? "User enabled" : "User disabled")
    }

    func update(scenePhase: ScenePhase) {
        let next: LifecycleState
        switch scenePhase {
        case .active: next = .active
        case .inactive: next = .inactive
        case .background: next = .background
        @unknown default: next = .unknown
        }
        guard lifecycleState != next else { return }
        lifecycleState = next
        state.setLifecycleState(next)
        reconcileSystemIdleTimer(reason: "Scene changed")
    }

    private func reconcileSystemIdleTimer(reason: String) {
        let desired = state.shouldDisableIdleTimer
        if UIApplication.shared.isIdleTimerDisabled != desired {
            UIApplication.shared.isIdleTimerDisabled = desired
        }
        appliedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        appendEvent("\(reason): \(lifecycleState.rawValue); user=\(userKeepAwake); applied=\(appliedIdleTimerDisabled)")
    }

    private func appendEvent(_ event: String) {
        events.insert(event, at: 0)
        events = Array(events.prefix(12))
    }
}

@main
struct LifecycleExperimentApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = LifecycleExperimentModel()

    var body: some Scene {
        WindowGroup {
            VStack(alignment: .leading, spacing: 12) {
                Text("MacDock iOS Lifecycle Experiment")
                    .font(.headline)
                Text("Lifecycle: \(model.lifecycleState.rawValue)")
                Text("Keep Screen Awake preference: \(model.userKeepAwake ? "ON" : "OFF")")
                Text("Idle timer currently disabled: \(model.appliedIdleTimerDisabled ? "YES" : "NO")")
                Toggle("Keep Screen Awake", isOn: Binding(
                    get: { model.userKeepAwake },
                    set: { model.setKeepAwake($0) }
                ))
                .accessibilityIdentifier("keep-awake-toggle")
                Text("The setting is opt-in and applies only while the app is foreground active. Manual device locking remains available.")
                    .font(.footnote)
                Divider()
                Text("Recent lifecycle events")
                    .font(.subheadline)
                ForEach(Array(model.events.enumerated()), id: \.offset) { _, event in
                    Text(event)
                        .font(.caption)
                }
                Spacer()
            }
            .padding()
            .onAppear { model.update(scenePhase: scenePhase) }
            .onChange(of: scenePhase) { _, newPhase in
                model.update(scenePhase: newPhase)
            }
        }
    }
}
