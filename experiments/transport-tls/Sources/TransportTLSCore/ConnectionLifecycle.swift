public enum ConnectionTerminalOutcome: Equatable, Sendable {
    case failed
    case timedOut
    case cancelled
    case completed
}

public struct ConnectionLifecycle: Sendable {
    public private(set) var terminalOutcome: ConnectionTerminalOutcome?

    public init() {}

    public mutating func begin() {
        terminalOutcome = nil
    }

    @discardableResult
    public mutating func finish(_ outcome: ConnectionTerminalOutcome) -> Bool {
        guard terminalOutcome == nil else { return false }
        terminalOutcome = outcome
        return true
    }
}
