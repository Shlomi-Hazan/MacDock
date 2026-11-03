import Foundation
import Testing
@testable import TransportTLSCore

@Test func encodesLengthPrefixedPayload() {
    let payload = Data("IPHONE-HELLO/1\n".utf8)
    let frame = FrameCodec.encode(payload)

    #expect(frame != nil)
    #expect(frame?.prefix(4) == Data([0, 0, 0, UInt8(payload.count)]))
    #expect(frame?.suffix(payload.count) == payload)
}

@Test func rejectsInvalidFrameLengths() {
    #expect(FrameCodec.decodeLength(from: Data([0, 0, 0, 0])) == nil)
    #expect(FrameCodec.decodeLength(from: Data([0, 0, 4, 1])) == nil)
    #expect(FrameCodec.decodeLength(from: Data([0, 0, 0, 5])) == 5)
    #expect(FrameCodec.decodeLength(from: Data([0, 0, 0])) == nil)
}

@Test func decodesFragmentedHeaderAndPayload() throws {
    let payload = Data("MAC-ACK/1\n".utf8)
    let frame = try #require(FrameCodec.encode(payload))
    var decoder = FrameDecoder()

    #expect(try decoder.append(Data(frame.prefix(2))).isEmpty)
    #expect(try decoder.append(Data(frame[2..<5])).isEmpty)
    #expect(try decoder.append(Data(frame.dropFirst(5))) == [payload])
}

@Test func decodesMultipleFramesFromOneRead() throws {
    let first = try #require(FrameCodec.encode(Data("one".utf8)))
    let second = try #require(FrameCodec.encode(Data("two".utf8)))
    var decoder = FrameDecoder()

    #expect(try decoder.append(first + second) == [Data("one".utf8), Data("two".utf8)])
}

@Test func rejectsEmptyOversizedAndTruncatedFrames() throws {
    var emptyDecoder = FrameDecoder()
    #expect(throws: FrameDecoderError.emptyPayload) {
        _ = try emptyDecoder.append(Data([0, 0, 0, 0]))
    }

    var oversizedDecoder = FrameDecoder()
    #expect(throws: FrameDecoderError.oversizedPayload(1_025)) {
        _ = try oversizedDecoder.append(Data([0, 0, 4, 1]))
    }

    let frame = try #require(FrameCodec.encode(Data("partial".utf8)))
    var truncatedDecoder = FrameDecoder()
    _ = try truncatedDecoder.append(Data(frame.dropLast()))
    #expect(throws: FrameDecoderError.truncatedFrame) {
        try truncatedDecoder.finish()
    }
}

@Test func decodesUnalignedHeaderWithoutUnsafeLoads() throws {
    let payload = Data([0x01, 0x02, 0x03])
    var decoder = FrameDecoder()
    #expect(try decoder.append(Data([0, 0, 0, 3, 1, 2, 3])) == [payload])
}

@Test func unexpectedAcknowledgmentIsNotAccepted() throws {
    let unexpected = Data("WRONG-ACK/1\n".utf8)
    let expected = Data("MAC-ACK/1\n".utf8)
    var decoder = FrameDecoder()
    let frame = try #require(FrameCodec.encode(unexpected))
    let result = try decoder.append(frame)
    #expect(result.count == 1)
    #expect(result[0] != expected)
}
