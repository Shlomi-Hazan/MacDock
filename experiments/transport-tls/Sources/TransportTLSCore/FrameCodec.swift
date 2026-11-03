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
        let length = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let integerLength = Int(length)
        return integerLength > 0 && integerLength <= maximumPayloadLength ? integerLength : nil
    }
}
