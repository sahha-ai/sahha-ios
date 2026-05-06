import Foundation
import CryptoKit

enum UUIDFactory {
    // Default namespace UUID (DNS namespace per RFC 4122)
    private static let defaultNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    private static let defaultNamespaceBytes = uuidToBigEndianBytes(defaultNamespace)
    
    static func v5(from components: [Any]) -> UUID {
        let name = components.map { "\($0)" }.joined()
        return v5(namespace: defaultNamespace, name: name)
    }

    static func v5(namespace: UUID, name: String) -> UUID {
        let namespaceBytes = (namespace == defaultNamespace)
            ? defaultNamespaceBytes
            : uuidToBigEndianBytes(namespace)
        let nameBytes = Array(name.utf8)
        let data = namespaceBytes + nameBytes

        let hash = Insecure.SHA1.hash(data: Data(data))
        var bytes = Array(hash.prefix(16))

        // Set version (5)
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        // Set variant (RFC 4122)
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func uuidToBigEndianBytes(_ uuid: UUID) -> [UInt8] {
        let bytes = uuid.uuid
        return [
            bytes.0, bytes.1, bytes.2, bytes.3,
            bytes.4, bytes.5,
            bytes.6, bytes.7,
            bytes.8, bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15
        ]
    }
}
