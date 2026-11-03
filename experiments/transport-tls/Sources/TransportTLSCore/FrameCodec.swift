import Foundation

public enum FrameCodec {
    public static let maximumPayloadLength = 1_024

    public static func encode(_ payload: Data) -> Data? {
        guard !payload.isEmpty, payload.count <= maximumPayloadLength else { return nil }
        var length = UInt32(payload.count).bigEndian
        return Data(bytes: &length, count: MemoryLayout<UInt32>.size) + payload
    }

    public static func decodeLength(from header: Data) -> Int? {
        guard header.count == MemoryLayout<UInt32>.size else { return nil }
        let bytes = header.map { UInt32($0) }
        let length = (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]
        let integerLength = Int(length)
        return integerLength > 0 && integerLength <= maximumPayloadLength ? integerLength : nil
    }
}

public enum FrameDecoderError: Error, Equatable {
    case emptyPayload
    case oversizedPayload(Int)
    case truncatedFrame
    case excessiveBufferedData
}

public struct FrameDecoder: Sendable {
    public static let maximumBufferedBytes = FrameCodec.maximumPayloadLength * 4

    private var buffer = Data()

    public init() {}

    public mutating func append(_ data: Data) throws -> [Data] {
        guard buffer.count + data.count <= Self.maximumBufferedBytes else {
            throw FrameDecoderError.excessiveBufferedData
        }
        buffer.append(data)

        var frames = [Data]()
        while buffer.count >= 4 {
            let header = Data(buffer.prefix(4))
            guard let length = FrameCodec.decodeLength(from: header) else {
                let rawLength = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
                if rawLength == 0 { throw FrameDecoderError.emptyPayload }
                throw FrameDecoderError.oversizedPayload(Int(rawLength))
            }
            let frameLength = 4 + length
            guard buffer.count >= frameLength else { break }
            frames.append(Data(buffer[4..<frameLength]))
            buffer.removeSubrange(0..<frameLength)
        }
        return frames
    }

    public mutating func finish() throws {
        if !buffer.isEmpty { throw FrameDecoderError.truncatedFrame }
    }
}
