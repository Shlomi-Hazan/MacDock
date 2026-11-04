import Foundation

public enum ProtocolFramingError: Error, Equatable, Sendable {
    case emptyMessageType
    case messageTypeTooLong
    case nonASCIIMessageType
    case unsupportedVersion(UInt16)
    case payloadTooLarge(Int)
    case invalidFrameLength(UInt32)
    case oversizedFrame(UInt32)
    case malformedEnvelope
    case decoderFailed
    case truncatedFrame(expected: Int, received: Int)
}

public struct ProtocolEnvelope: Codable, Equatable, Sendable {
    public static let currentVersion: UInt16 = 1
    public static let maximumRawPayloadLength = 64 * 1024

    public let protocolVersion: UInt16
    public let messageType: String
    public let requestID: UUID?
    public let payload: Data

    public init(
        protocolVersion: UInt16 = ProtocolEnvelope.currentVersion,
        messageType: String,
        requestID: UUID? = nil,
        payload: Data = Data()
    ) throws {
        try Self.validate(
            protocolVersion: protocolVersion,
            messageType: messageType,
            payload: payload
        )

        self.protocolVersion = protocolVersion
        self.messageType = messageType
        self.requestID = requestID
        self.payload = payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let protocolVersion = try container.decode(UInt16.self, forKey: .protocolVersion)
        let messageType = try container.decode(String.self, forKey: .messageType)
        let requestID = try container.decodeIfPresent(UUID.self, forKey: .requestID)
        let payload = try container.decodeIfPresent(Data.self, forKey: .payload) ?? Data()

        try Self.validate(
            protocolVersion: protocolVersion,
            messageType: messageType,
            payload: payload
        )

        self.protocolVersion = protocolVersion
        self.messageType = messageType
        self.requestID = requestID
        self.payload = payload
    }

    private static func validate(
        protocolVersion: UInt16,
        messageType: String,
        payload: Data
    ) throws {
        guard protocolVersion == currentVersion else {
            throw ProtocolFramingError.unsupportedVersion(protocolVersion)
        }
        guard !messageType.isEmpty else {
            throw ProtocolFramingError.emptyMessageType
        }
        guard messageType.utf8.count <= 64 else {
            throw ProtocolFramingError.messageTypeTooLong
        }
        guard messageType.unicodeScalars.allSatisfy({ $0.value < 128 }) else {
            throw ProtocolFramingError.nonASCIIMessageType
        }
        guard payload.count <= maximumRawPayloadLength else {
            throw ProtocolFramingError.payloadTooLarge(payload.count)
        }
    }
}

public enum ProtocolFrameCodec {
    public static let headerLength = MemoryLayout<UInt32>.size
    public static let maximumEncodedFramePayloadLength = 64 * 1024

    public static func encode(_ envelope: ProtocolEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let encodedEnvelope = try encoder.encode(envelope)
        guard encodedEnvelope.count <= maximumEncodedFramePayloadLength else {
            throw ProtocolFramingError.payloadTooLarge(encodedEnvelope.count)
        }

        var frame = Data(capacity: headerLength + encodedEnvelope.count)
        var length = UInt32(encodedEnvelope.count).bigEndian
        withUnsafeBytes(of: &length) { frame.append(contentsOf: $0) }
        frame.append(encodedEnvelope)
        return frame
    }

    public static func decode(_ encodedEnvelope: Data) throws -> ProtocolEnvelope {
        guard encodedEnvelope.count <= maximumEncodedFramePayloadLength else {
            throw ProtocolFramingError.oversizedFrame(UInt32(encodedEnvelope.count))
        }

        do {
            return try JSONDecoder().decode(ProtocolEnvelope.self, from: encodedEnvelope)
        } catch let error as ProtocolFramingError {
            throw error
        } catch {
            throw ProtocolFramingError.malformedEnvelope
        }
    }
}

public struct ProtocolFrameDecoder: Sendable {
    private var buffer = Data()
    private var expectedPayloadLength: Int?
    private var failed = false

    public init() {}

    public mutating func append(_ input: Data) throws -> [ProtocolEnvelope] {
        guard !failed else { throw ProtocolFramingError.decoderFailed }

        var offset = 0
        var decodedFrames: [ProtocolEnvelope] = []

        while offset < input.count {
            if expectedPayloadLength == nil {
                let requiredHeaderBytes = ProtocolFrameCodec.headerLength - buffer.count
                let bytesToAppend = min(requiredHeaderBytes, input.count - offset)
                buffer.append(input[offset..<(offset + bytesToAppend)])
                offset += bytesToAppend

                guard buffer.count == ProtocolFrameCodec.headerLength else { continue }

                let declaredLength = try Self.readLength(from: buffer)
                guard declaredLength > 0 else {
                    failed = true
                    throw ProtocolFramingError.invalidFrameLength(declaredLength)
                }
                guard declaredLength <= UInt32(ProtocolFrameCodec.maximumEncodedFramePayloadLength) else {
                    failed = true
                    throw ProtocolFramingError.oversizedFrame(declaredLength)
                }

                expectedPayloadLength = Int(declaredLength)
            }

            guard let expectedPayloadLength else { continue }
            let frameSize = ProtocolFrameCodec.headerLength + expectedPayloadLength
            let bytesNeeded = frameSize - buffer.count
            let bytesToAppend = min(bytesNeeded, input.count - offset)
            buffer.append(input[offset..<(offset + bytesToAppend)])
            offset += bytesToAppend

            guard buffer.count == frameSize else { continue }

            let payload = buffer.dropFirst(ProtocolFrameCodec.headerLength)
            do {
                decodedFrames.append(try ProtocolFrameCodec.decode(Data(payload)))
            } catch {
                failed = true
                throw error
            }

            buffer.removeAll(keepingCapacity: true)
            self.expectedPayloadLength = nil
        }

        return decodedFrames
    }

    public mutating func finish() throws {
        guard !failed else { throw ProtocolFramingError.decoderFailed }
        guard buffer.isEmpty else {
            let expected = expectedPayloadLength.map { ProtocolFrameCodec.headerLength + $0 }
                ?? ProtocolFrameCodec.headerLength
            failed = true
            throw ProtocolFramingError.truncatedFrame(expected: expected, received: buffer.count)
        }
    }

    public mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        expectedPayloadLength = nil
        failed = false
    }

    private static func readLength(from header: Data) throws -> UInt32 {
        guard header.count == ProtocolFrameCodec.headerLength else {
            throw ProtocolFramingError.invalidFrameLength(0)
        }

        return header.reduce(UInt32.zero) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
    }
}
