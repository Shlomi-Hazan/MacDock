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
