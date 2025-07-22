final actor DefaultTokenStore: TokenStore {
    private let secureStore: SecureStore
    private let storageKey = StorageKeys.authToken

    init(secureStore: SecureStore = KeychainStore()) {
        self.secureStore = secureStore
    }

    func save(_ token: TokenResponse) async throws {
        try await secureStore.set(token, forKey: storageKey)
    }

    func get() async throws -> TokenResponse? {
        try await secureStore.get(storageKey)
    }

    func delete() async throws {
        try await secureStore.remove(storageKey)
    }
}
