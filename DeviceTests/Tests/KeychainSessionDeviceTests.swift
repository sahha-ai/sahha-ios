import Foundation
import Security
import Testing
@testable import Sahha

/// The persisted session in the real device keychain. The simulator's keychain has no
/// lock state and no data protection, so it cannot show the item's accessibility class,
/// which is what lets a background launch before first unlock fail cleanly rather than
/// read as signed out.
///
/// Uses its own keychain service, so the host app's own session (if any) is untouched.
@Suite("Keychain session on a real device", .serialized)
struct KeychainSessionDeviceTests {
    private static let service = "ai.sahha.devicetests.keychain"
    private let keychain = KeychainStorage(service: Self.service)
    private let key = StorageKeys.Keychain.token.rawValue

    @Test("A saved session is read back by a fresh store and by the synchronous session reader")
    func sessionSurvivesAFreshStore() async throws {
        try keychain.removeObject(forKey: key)
        defer { try? keychain.removeObject(forKey: key) }

        let pair = TokenResponse(profileToken: "device-test-profile-\(UUID())", refreshToken: "device-test-refresh-\(UUID())")
        let writer = TokenStore(storage: keychain, userDefaults: InMemoryDefaults(), key: key, logger: SilentErrorLogger())
        try await writer.saveToken(pair)

        // A new store reads the keychain in its initialiser, as on a relaunch.
        let relaunched = TokenStore(storage: keychain, userDefaults: InMemoryDefaults(), key: key, logger: SilentErrorLogger())
        #expect(await relaunched.token()?.profileToken == pair.profileToken)
        #expect(await relaunched.token()?.refreshToken == pair.refreshToken)
        #expect(await relaunched.hasUnreadablePersistedSession() == false)

        // What Sahha.isAuthenticated and Sahha.profileToken read.
        #expect(SessionReader(keychain: keychain).profileToken() == pair.profileToken)
    }

    @Test("The session is stored as readable after first unlock, so background launches can read it")
    func sessionIsAccessibleAfterFirstUnlock() async throws {
        try keychain.removeObject(forKey: key)
        defer { try? keychain.removeObject(forKey: key) }

        let store = TokenStore(storage: keychain, userDefaults: InMemoryDefaults(), key: key, logger: SilentErrorLogger())
        try await store.saveToken(TokenResponse(profileToken: "p", refreshToken: "r"))

        let accessible = try #require(accessibilityClass(forKey: key))
        #expect(accessible == (kSecAttrAccessibleAfterFirstUnlock as String))
    }

    @Test("Clearing the session removes it from the keychain")
    func clearingRemovesTheItem() async throws {
        defer { try? keychain.removeObject(forKey: key) }

        let store = TokenStore(storage: keychain, userDefaults: InMemoryDefaults(), key: key, logger: SilentErrorLogger())
        try await store.saveToken(TokenResponse(profileToken: "p", refreshToken: "r"))
        await store.clearToken()

        #expect(SessionReader(keychain: keychain).profileToken() == nil)
        let relaunched = TokenStore(storage: keychain, userDefaults: InMemoryDefaults(), key: key, logger: SilentErrorLogger())
        #expect(await relaunched.token() == nil)
    }

    private func accessibilityClass(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }
        return attributes[kSecAttrAccessible as String] as? String
    }
}
