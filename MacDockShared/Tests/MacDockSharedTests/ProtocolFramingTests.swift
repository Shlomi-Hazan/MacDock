import Foundation
import Testing
@testable import MacDockShared

struct ProtocolFramingTests {
    @Test
    func validEnvelopeRoundTrips() throws {
        let requestID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let envelope = try ProtocolEnvelope(
            messageType: "foundation.test",
            requestID: requestID,
            payload: Data("hello".utf8)
        )

        let frame = try ProtocolFrameCodec.encode(envelope)
        var decoder = ProtocolFrameDecoder()
        let decoded = try decoder.append(frame)

        #expect(decoded == [envelope])
    }

    @Test
    func headerAndPayloadCanBeFragmented() throws {
        let envelope = try ProtocolEnvelope(messageType: "fragment", payload: Data("payload".utf8))
        let frame = try ProtocolFrameCodec.encode(envelope)
        var decoder = ProtocolFrameDecoder()
        var decoded: [ProtocolEnvelope] = []

        for byte in frame {
            decoded.append(contentsOf: try decoder.append(Data([byte])))
        }

        #expect(decoded == [envelope])
    }

    @Test
    func multipleFramesDecodeFromOneInput() throws {
        let first = try ProtocolFrameCodec.encode(ProtocolEnvelope(messageType: "one"))
        let second = try ProtocolFrameCodec.encode(ProtocolEnvelope(messageType: "two"))
        var decoder = ProtocolFrameDecoder()

        let decoded = try decoder.append(first + second)

        #expect(decoded.map(\.messageType) == ["one", "two"])
    }

    @Test
    func emptyInputIsIncompleteButNotMalformed() throws {
        var decoder = ProtocolFrameDecoder()

        #expect(try decoder.append(Data()).isEmpty)
        try decoder.finish()
    }

    @Test
    func invalidAndOversizedLengthsAreRejectedBeforePayloadDecode() throws {
        var zeroLengthDecoder = ProtocolFrameDecoder()
        #expect(throws: ProtocolFramingError.invalidFrameLength(0)) {
            try zeroLengthDecoder.append(Data([0, 0, 0, 0]))
        }

        var oversizedDecoder = ProtocolFrameDecoder()
        let oversizedLength = UInt32(ProtocolFrameCodec.maximumEncodedFramePayloadLength + 1).bigEndian
        var oversizedHeader = Data()
        withUnsafeBytes(of: oversizedLength) { oversizedHeader.append(contentsOf: $0) }

        #expect(throws: ProtocolFramingError.oversizedFrame(65_537)) {
            try oversizedDecoder.append(oversizedHeader)
        }
    }

    @Test
    func unsupportedVersionAndMalformedEnvelopeAreRejected() throws {
        let unsupportedVersionJSON = Data(#"{"messageType":"test","protocolVersion":2}"#.utf8)
        #expect(throws: ProtocolFramingError.unsupportedVersion(2)) {
            _ = try ProtocolFrameCodec.decode(unsupportedVersionJSON)
        }

        let malformed = Data("not-json".utf8)
        #expect(throws: ProtocolFramingError.malformedEnvelope) {
            _ = try ProtocolFrameCodec.decode(malformed)
        }
    }

    @Test
    func invalidMessageTypesAndPayloadsAreRejected() throws {
        #expect(throws: ProtocolFramingError.emptyMessageType) {
            _ = try ProtocolEnvelope(messageType: "")
        }

        #expect(throws: ProtocolFramingError.nonASCIIMessageType) {
            _ = try ProtocolEnvelope(messageType: "héllo")
        }

        #expect(throws: ProtocolFramingError.messageTypeTooLong) {
            _ = try ProtocolEnvelope(messageType: String(repeating: "a", count: 65))
        }

        #expect(throws: ProtocolFramingError.payloadTooLarge(65_537)) {
            _ = try ProtocolEnvelope(
                messageType: "large",
                payload: Data(repeating: 0, count: ProtocolEnvelope.maximumRawPayloadLength + 1)
            )
        }
    }

    @Test
    func encodedFrameLimitIsAuthoritativeForRawDataPayloads() throws {
        let nearLimit = try ProtocolEnvelope(
            messageType: "near-limit",
            payload: Data(repeating: 65, count: 49_000)
        )
        let nearLimitFrame = try ProtocolFrameCodec.encode(nearLimit)
        let encodedLength = nearLimitFrame.count - ProtocolFrameCodec.headerLength

        #expect(encodedLength <= ProtocolFrameCodec.maximumEncodedFramePayloadLength)
        #expect(encodedLength > ProtocolFrameCodec.maximumEncodedFramePayloadLength - 512)

        let rawPayloadWithinRawLimit = try ProtocolEnvelope(
            messageType: "encoded-too-large",
            payload: Data(repeating: 65, count: 49_103)
        )
        let jsonEncoder = JSONEncoder()
        jsonEncoder.outputFormatting = [.sortedKeys]
        let encodedEnvelope = try jsonEncoder.encode(rawPayloadWithinRawLimit)

        #expect(encodedEnvelope.count > ProtocolFrameCodec.maximumEncodedFramePayloadLength)
        #expect(throws: ProtocolFramingError.payloadTooLarge(encodedEnvelope.count)) {
            _ = try ProtocolFrameCodec.encode(rawPayloadWithinRawLimit)
        }
    }

    @Test
    func truncatedFramesAreReportedOnlyAtEndOfStream() throws {
        let envelope = try ProtocolEnvelope(messageType: "truncated")
        let frame = try ProtocolFrameCodec.encode(envelope)
        var decoder = ProtocolFrameDecoder()

        _ = try decoder.append(frame.dropLast())
        #expect(throws: ProtocolFramingError.truncatedFrame(expected: frame.count, received: frame.count - 1)) {
            try decoder.finish()
        }
    }

    @Test
    func decoderCanRecoverAfterReset() throws {
        let badFrame = Data([0, 0, 0, 0])
        let envelope = try ProtocolEnvelope(messageType: "recovered")
        let goodFrame = try ProtocolFrameCodec.encode(envelope)
        var decoder = ProtocolFrameDecoder()

        #expect(throws: ProtocolFramingError.invalidFrameLength(0)) {
            try decoder.append(badFrame)
        }
        decoder.reset()

        #expect(try decoder.append(goodFrame) == [envelope])
    }

    @Test
    func partialHeaderIsTruncatedOnlyWhenStreamFinishes() throws {
        var decoder = ProtocolFrameDecoder()

        #expect(try decoder.append(Data([0, 0])).isEmpty)
        #expect(throws: ProtocolFramingError.truncatedFrame(expected: 4, received: 2)) {
            try decoder.finish()
        }
    }

    @Test
    func decoderRemainsFailedUntilResetAfterAnError() throws {
        var decoder = ProtocolFrameDecoder()

        #expect(throws: ProtocolFramingError.invalidFrameLength(0)) {
            try decoder.append(Data([0, 0, 0, 0]))
        }
        #expect(throws: ProtocolFramingError.decoderFailed) {
            try decoder.append(Data())
        }

        decoder.reset()
        let envelope = try ProtocolEnvelope(messageType: "after-reset")
        #expect(try decoder.append(ProtocolFrameCodec.encode(envelope)) == [envelope])
    }
}
