import Foundation
import CryptoKit

enum UUIDFactory {
    static func v5(from input: String) -> UUID {
        let hash = Insecure.SHA1.hash(data: Data(input.utf8))
        let bytes = Array(hash.prefix(16))
        
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            (bytes[6] & 0x0F) | 0x50, bytes[7], // version 5
            (bytes[8] & 0x3F) | 0x80, bytes[9], // RFC 4122 variant
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
