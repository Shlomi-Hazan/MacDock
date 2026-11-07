import XCTest
@testable import MTLSPeerPinningCore

final class TrustStateTests: XCTestCase {
    func testTLSReadinessDoesNotCreateTrust() {
        var machine = TrustStateMachine()
        XCTAssertEqual(machine.state, .untrusted)
        XCTAssertTrue(machine.apply(.begin(sessionID: "fixture-1")))
        XCTAssertEqual(machine.state, .pending(sessionID: "fixture-1"))
        XCTAssertFalse(machine.apply(.begin(sessionID: "fixture-2")))
    }

    func testCommitRequiresExplicitConfirmation() {
        var machine = TrustStateMachine()
        XCTAssertTrue(machine.apply(.begin(sessionID: "fixture-1")))
        XCTAssertTrue(machine.apply(.confirm(peerFingerprint: String(repeating: "a", count: 64))))
        XCTAssertEqual(machine.state, .committed(peerFingerprint: String(repeating: "a", count: 64)))
    }

    func testInterruptedPairingDoesNotCommit() {
        var machine = TrustStateMachine()
        XCTAssertTrue(machine.apply(.begin(sessionID: "fixture-1")))
        XCTAssertTrue(machine.apply(.interrupted))
        XCTAssertEqual(machine.state, .recoveryRequired)
        XCTAssertFalse(machine.apply(.confirm(peerFingerprint: "unexpected")))
    }

    func testIdentityChangeFailsClosed() {
        var machine = TrustStateMachine()
        XCTAssertTrue(machine.apply(.begin(sessionID: "fixture-1")))
        XCTAssertTrue(machine.apply(.confirm(peerFingerprint: "peer-a")))
        XCTAssertTrue(machine.apply(.identityChanged))
        XCTAssertEqual(machine.state, .recoveryRequired)
    }
}
