import Foundation

extension Encodable {
    /// Encodes the value to JSON (using the provided encoder) and returns its SHA-256 hash as a hex string.
    ///
    /// - Parameter encoder: The `JSONEncoder` to use; defaults to a new `JSONEncoder()`.
    /// - Throws: Forwarding any encoding errors.
    /// - Returns: A 64-character hex string representing the SHA-256 hash of the JSON-encoded value.
    func sha256Hash(using encoder: JSONEncoder = JSONEncoder()) throws -> String {
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(self)
        return data.sha256Hex()
    }

    /// Attempts to compute the SHA-256 hash of the JSON-encoded value, safely handling any errors.
    ///
    /// - Parameters:
    ///   - encoder: The `JSONEncoder` to use for encoding. Defaults to a new `JSONEncoder()`.
    ///   - fallback: A closure that provides a fallback string if hashing fails. Defaults to a random UUID string.
    ///   - logError: Optional closure that is called with the thrown error if hashing fails..
    ///
    /// - Returns: The SHA-256 hash of the JSON-encoded value, or the result of `fallback` if an error occurs.
    ///
    /// Use this when you want to safely hash an Encodable value without handling errors at every call site.
    func safeSha256Hash(
        using encoder: JSONEncoder = JSONEncoder(),
        fallback: @autoclosure () -> String = UUID().uuidString,
        logError: ((Error) -> Void)? = nil
    ) -> String {
        do {
            return try sha256Hash(using: encoder)
        } catch {
            logError?(error)
            return fallback()
        }
    }
}
