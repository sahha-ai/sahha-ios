import Foundation
import CryptoKit

extension Data {
    /// Computes the SHA-256 digest of the data and returns it as a lowercase hex string.
    ///
    /// - Returns: A 64-character hex string representing the SHA-256 hash.
    func sha256Hex() -> String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
