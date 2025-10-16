import Foundation

extension Data {
    func toUInt32(at offset: Int) -> UInt32 {
        let range = offset..<(offset+UInt32.byteWidth)
        let bytes = self[range]
        return bytes.withUnsafeBytes { ptr in
            var value: UInt32 = 0
            memcpy(&value, ptr.baseAddress!, UInt32.byteWidth)
            return value
        }
    }
}

