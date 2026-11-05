import Foundation

public enum TransportDiagnosticMessage: Equatable, Sendable {
    case hello
    case acknowledgment
}

public enum TransportDiagnosticError: Error, Equatable, Sendable {
    case unexpectedMessageType
    case unexpectedPayload
    case unsupportedDiagnosticMessage
}

public enum TransportDiagnosticCodec {
    public static let helloType = "macdock.foundation.diagnostic.hello"
    public static let acknowledgmentType = "macdock.foundation.diagnostic.ack"
    public static let fixedPayload = Data("macdock-foundation-diagnostic-v1".utf8)

    public static func helloEnvelope() throws -> ProtocolEnvelope {
        try ProtocolEnvelope(messageType: helloType, payload: fixedPayload)
    }

    public static func acknowledgmentEnvelope() throws -> ProtocolEnvelope {
        try ProtocolEnvelope(messageType: acknowledgmentType, payload: fixedPayload)
    }

    public static func decode(_ envelope: ProtocolEnvelope) throws -> TransportDiagnosticMessage {
        guard envelope.requestID == nil else { throw TransportDiagnosticError.unexpectedPayload }
        guard envelope.payload == fixedPayload else { throw TransportDiagnosticError.unexpectedPayload }

        switch envelope.messageType {
        case helloType:
            return .hello
        case acknowledgmentType:
            return .acknowledgment
        default:
            throw TransportDiagnosticError.unsupportedDiagnosticMessage
        }
    }
}

public enum TransportDiagnosticPhase: Equatable, Sendable {
    case idle
    case connecting
    case ready
    case failed
    case cancelled
}

public struct TransportDiagnosticState: Equatable, Sendable {
    public let phase: TransportDiagnosticPhase
    public let diagnosticExchangeCompleted: Bool

    public init(
        phase: TransportDiagnosticPhase = .idle,
        diagnosticExchangeCompleted: Bool = false
    ) {
        self.phase = phase
        self.diagnosticExchangeCompleted = diagnosticExchangeCompleted
    }
}

public enum TransportDiagnosticReducer {
    public static func reduce(
        _ state: TransportDiagnosticState,
        _ phase: TransportDiagnosticPhase,
        exchangeCompleted: Bool = false
    ) -> TransportDiagnosticState {
        TransportDiagnosticState(
            phase: phase,
            diagnosticExchangeCompleted: exchangeCompleted
        )
    }
}
