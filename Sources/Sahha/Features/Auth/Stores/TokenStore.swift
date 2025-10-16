import Foundation

actor TokenStore: TokenStoreProtocol {
    private let key: String
    private let storage: KeychainStorageProtocol
    private let logger: ErrorLoggerProtocol

    private var cached: TokenResponse?

    init(storage: KeychainStorageProtocol, key: String = StorageKeys.Keychain.token, logger: ErrorLoggerProtocol) {
        self.storage = storage
        self.key = key
        self.logger = logger

        do {
            self.cached = try self.storage.object(forKey: key)
            Sahha.authSnapshot.profileToken = cached?.profileToken
        } catch {
            self.logger.postError(error)
        }
    }

    func saveToken(_ token: TokenResponse) throws {
        try storage.setObject(token, forKey: key)
        Sahha.authSnapshot.profileToken = token.profileToken
        self.cached = token
    }
    
    func token() -> TokenResponse? {
        cached
    }

    func profileToken() -> String? {
        cached?.profileToken
    }

    func refreshToken() -> String? {
        cached?.refreshToken
    }

    func dispose() async {
        cached = nil
        Sahha.authSnapshot.profileToken = nil
        do {
            try storage.removeObject(forKey: key)
        } catch {
            logger.postError(error)
        }
    }
}
