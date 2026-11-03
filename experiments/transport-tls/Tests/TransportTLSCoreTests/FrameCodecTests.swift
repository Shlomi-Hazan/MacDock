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
