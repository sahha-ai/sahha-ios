import Foundation
@testable import Sahha

/// In-memory keychain double with a scriptable failure mode.
final class MockKeychainStorage: KeychainStorageProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]
    private var scriptedError: Error?

    /// When set, every subsequent operation throws this error (a keychain that has
    /// become unreadable/unwritable), until cleared.
    var errorToThrow: Error? {
        get { lock.lock(); defer { lock.unlock() }; return scriptedError }
        set { lock.lock(); defer { lock.unlock() }; scriptedError = newValue }
    }

    var storedKeys: [String] {
        lock.lock(); defer { lock.unlock() }
        return Array(store.keys)
    }

    func set(_ value: Data, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        if let scriptedError { throw scriptedError }
        store[key] = value
    }
    func get(forKey key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        if let scriptedError { throw scriptedError }
        return store[key]
    }
    func removeObject(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        if let scriptedError { throw scriptedError }
        store.removeValue(forKey: key)
    }
}
