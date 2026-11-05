import Foundation
import Testing
@testable import MacDockShared

struct TransportDiagnosticTests {
    @Test
    func fixedHelloAndAcknowledgmentRoundTripThroughFraming() throws {
        let hello = try TransportDiagnosticCodec.helloEnvelope()
        let acknowledgment = try TransportDiagnosticCodec.acknowledgmentEnvelope()

        let helloFrame = try ProtocolFrameCodec.encode(hello)
        let acknowledgmentFrame = try ProtocolFrameCodec.encode(acknowledgment)
        var decoder = ProtocolFrameDecoder()
        let messages = try decoder.append(helloFrame + acknowledgmentFrame)

        #expect(try TransportDiagnosticCodec.decode(messages[0]) == .hello)
        #expect(try TransportDiagnosticCodec.decode(messages[1]) == .acknowledgment)
    }

    @Test
    func unexpectedDiagnosticMessagesAreRejected() throws {
        let envelope = try ProtocolEnvelope(messageType: "macdock.foundation.unknown", payload: TransportDiagnosticCodec.fixedPayload)
        #expect(throws: TransportDiagnosticError.unsupportedDiagnosticMessage) {
            try TransportDiagnosticCodec.decode(envelope)
        }
    }

    @Test
    func diagnosticPayloadCannotCarryARequestID() throws {
        let envelope = try ProtocolEnvelope(
            messageType: TransportDiagnosticCodec.helloType,
            requestID: UUID(),
            payload: TransportDiagnosticCodec.fixedPayload
        )
        #expect(throws: TransportDiagnosticError.unexpectedPayload) {
            try TransportDiagnosticCodec.decode(envelope)
        }
    }

    @Test
    func transportReadyDoesNotMeanAuthenticated() {
        let state = TransportDiagnosticReducer.reduce(.init(), .ready)
        #expect(state.phase == .ready)
        #expect(!state.diagnosticExchangeCompleted)
    }
}
