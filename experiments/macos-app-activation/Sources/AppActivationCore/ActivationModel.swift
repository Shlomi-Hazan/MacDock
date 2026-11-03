import AppKit
import Foundation

public enum RequestedOperation: String, Sendable {
    case launch
    case activate
    case missing
}

public enum ObservedOutcome: String, Sendable {
    case requestAccepted
    case requestRejected
    case processRunning
    case activationAccepted
    case activationRejected
    case frontmostObserved
    case foregroundUnverified
    case timeout
    case unknown
}

public struct ProcessObservation: Sendable {
    public let isRunning: Bool
    public let isFrontmost: Bool
    public let isActive: Bool
    public let isHidden: Bool

    public init(isRunning: Bool, isFrontmost: Bool, isActive: Bool, isHidden: Bool) {
        self.isRunning = isRunning
        self.isFrontmost = isFrontmost
        self.isActive = isActive
        self.isHidden = isHidden
    }
}

public struct OperationReport: Sendable {
    public let operation: RequestedOperation
    public let requestOutcome: ObservedOutcome
    public let processObservation: ProcessObservation
    public let foregroundOutcome: ObservedOutcome
    public let errorDescription: String?

    public init(operation: RequestedOperation, requestOutcome: ObservedOutcome, processObservation: ProcessObservation, foregroundOutcome: ObservedOutcome, errorDescription: String? = nil) {
        self.operation = operation
        self.requestOutcome = requestOutcome
        self.processObservation = processObservation
        self.foregroundOutcome = foregroundOutcome
        self.errorDescription = errorDescription
    }
}

public enum ExperimentError: LocalizedError {
    case launchTimedOut
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .launchTimedOut:
            return "The launch completion handler did not return before the bounded timeout."
        case .launchFailed(let message):
            return message
        }
    }
}

private final class CallbackBox<Value>: @unchecked Sendable {
    var value: Value?
}

public struct ApplicationController {
    public let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func observe(bundleURL: URL) -> ProcessObservation {
        let canonicalPath = bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        let runningApplication = workspace.runningApplications.first { application in
            guard let path = application.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path else { return false }
            return path == canonicalPath
        }
        let frontmost = workspace.frontmostApplication
        let isFrontmost = runningApplication != nil && frontmost?.processIdentifier == runningApplication?.processIdentifier
        return ProcessObservation(
            isRunning: runningApplication != nil,
            isFrontmost: isFrontmost,
            isActive: runningApplication?.isActive ?? false,
            isHidden: runningApplication?.isHidden ?? false
        )
    }

    public func launch(bundleURL: URL, timeout: TimeInterval = 10) -> OperationReport {
        let before = observe(bundleURL: bundleURL)
        guard !before.isRunning else {
            return OperationReport(operation: .launch, requestOutcome: .unknown, processObservation: before, foregroundOutcome: .foregroundUnverified, errorDescription: "Target is already running; launch-only scenario was not issued.")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let launchResult = CallbackBox<Result<NSRunningApplication, Error>>()
        workspace.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration()) { application, error in
            if let application {
                launchResult.value = .success(application)
            } else {
                launchResult.value = .failure(error ?? ExperimentError.launchFailed("macOS returned no application and no error."))
            }
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            return OperationReport(operation: .launch, requestOutcome: .timeout, processObservation: observe(bundleURL: bundleURL), foregroundOutcome: .foregroundUnverified, errorDescription: ExperimentError.launchTimedOut.localizedDescription)
        }

        switch launchResult.value {
        case .success:
            let after = waitForRunning(bundleURL: bundleURL, timeout: timeout)
            return OperationReport(operation: .launch, requestOutcome: .requestAccepted, processObservation: after, foregroundOutcome: after.isFrontmost ? .frontmostObserved : .foregroundUnverified)
        case .failure(let error):
            return OperationReport(operation: .launch, requestOutcome: .requestRejected, processObservation: observe(bundleURL: bundleURL), foregroundOutcome: .foregroundUnverified, errorDescription: error.localizedDescription)
        case nil:
            return OperationReport(operation: .launch, requestOutcome: .unknown, processObservation: observe(bundleURL: bundleURL), foregroundOutcome: .foregroundUnverified, errorDescription: "No launch result was available.")
        }
    }

    public func activate(bundleURL: URL) -> OperationReport {
        let before = observe(bundleURL: bundleURL)
        guard let application = workspace.runningApplications.first(where: { running in
            running.bundleURL?.standardizedFileURL.resolvingSymlinksInPath().path == bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        }) else {
            return OperationReport(operation: .activate, requestOutcome: .requestRejected, processObservation: before, foregroundOutcome: .foregroundUnverified, errorDescription: "Target process was not running; activation was not issued.")
        }

        let accepted = application.activate(options: [.activateIgnoringOtherApps])
        let after = waitForFrontmost(bundleURL: bundleURL, timeout: 3)
        return OperationReport(
            operation: .activate,
            requestOutcome: accepted ? .activationAccepted : .activationRejected,
            processObservation: after,
            foregroundOutcome: after.isFrontmost ? .frontmostObserved : .foregroundUnverified,
            errorDescription: accepted ? nil : "NSRunningApplication.activate returned false."
        )
    }

    public func missing(bundleURL: URL) -> OperationReport {
        let semaphore = DispatchSemaphore(value: 0)
        let errorDescription = CallbackBox<String>()
        workspace.openApplication(at: bundleURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            errorDescription.value = error?.localizedDescription ?? "macOS returned no application and no error."
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success else {
            return OperationReport(operation: .missing, requestOutcome: .timeout, processObservation: observe(bundleURL: bundleURL), foregroundOutcome: .foregroundUnverified, errorDescription: ExperimentError.launchTimedOut.localizedDescription)
        }
        return OperationReport(operation: .missing, requestOutcome: .requestRejected, processObservation: observe(bundleURL: bundleURL), foregroundOutcome: .foregroundUnverified, errorDescription: errorDescription.value)
    }

    private func waitForRunning(bundleURL: URL, timeout: TimeInterval) -> ProcessObservation {
        let deadline = Date().addingTimeInterval(timeout)
        var result = observe(bundleURL: bundleURL)
        while !result.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            result = observe(bundleURL: bundleURL)
        }
        return result
    }

    private func waitForFrontmost(bundleURL: URL, timeout: TimeInterval) -> ProcessObservation {
        let deadline = Date().addingTimeInterval(timeout)
        var result = observe(bundleURL: bundleURL)
        while !result.isFrontmost && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
            result = observe(bundleURL: bundleURL)
        }
        return result
    }
}
