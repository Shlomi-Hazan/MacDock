import Foundation
import Testing
@testable import AppActivationCore

@Test func missingTargetIsNotReportedAsRunning() {
    let controller = ApplicationController()
    let observation = controller.observe(bundleURL: URL(fileURLWithPath: "/System/Applications/MacDockMissing.app"))
    #expect(!observation.isRunning)
    #expect(!observation.isFrontmost)
}

@Test func operationNamesRemainDistinct() {
    #expect(RequestedOperation.launch != .activate)
    #expect(ObservedOutcome.requestAccepted != .frontmostObserved)
}

@Test func missingApplicationReportsTheObservedNativeResult() {
    let report = ApplicationController().missing(bundleURL: URL(fileURLWithPath: "/System/Applications/MacDock-Missing.app"))
    #expect(report.requestOutcome == .requestRejected || report.requestOutcome == .unknown || report.requestOutcome == .requestAccepted)
    #expect(report.requestOutcome != .timeout)
    #expect(report.errorDescription != nil || report.requestOutcome == .requestAccepted)
}
