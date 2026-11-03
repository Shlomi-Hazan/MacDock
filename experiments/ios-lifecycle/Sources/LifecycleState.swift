public enum LifecycleState: String, CaseIterable, Sendable {
    case active = "Foreground active"
    case inactive = "Foreground inactive"
    case background = "Background"
    case unknown = "Unknown"
}

public struct KeepAwakeStateModel: Equatable, Sendable {
    public private(set) var userEnabled = false
    public private(set) var lifecycleState: LifecycleState = .unknown
    public private(set) var appliedIdleTimerDisabled = false

    public init() {}

    public mutating func setUserEnabled(_ enabled: Bool) {
        userEnabled = enabled
        reconcile()
    }

    public mutating func setLifecycleState(_ state: LifecycleState) {
        lifecycleState = state
        reconcile()
    }

    public var shouldDisableIdleTimer: Bool {
        userEnabled && lifecycleState == .active
    }

    private mutating func reconcile() {
        appliedIdleTimerDisabled = shouldDisableIdleTimer
    }
}
