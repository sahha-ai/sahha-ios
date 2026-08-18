import Foundation
@testable import Sahha

/// In-memory `UserDefaults` stand-in so tests never touch real storage.
///
/// Only the four primitives are implemented; the typed accessors arrive via the
/// protocol's default implementations, so every typed read routes through the
/// primitive getter and is observable via `readKeys`.
final class InMemoryStorage: UserDefaultsStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Any] = [:]
    private var reads: [String] = []
    private var writes: [String] = []

    /// Keys read through the primitive getter, in order (typed reads route here).
    var readKeys: [String] {
        lock.lock(); defer { lock.unlock() }
        return reads
    }

    /// Keys written through the primitive setter (including nil-removals), in order.
    var writtenKeys: [String] {
        lock.lock(); defer { lock.unlock() }
        return writes
    }

    func set(_ value: Any?, forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        writes.append(key)
        if let value { store[key] = value } else { store.removeValue(forKey: key) }
    }
    func get(forKey key: String) -> Any? {
        lock.lock(); defer { lock.unlock() }
        reads.append(key)
        return store[key]
    }
    func removeObject(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        store.removeValue(forKey: key)
    }
    func allKeys() -> [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys)
    }
}
