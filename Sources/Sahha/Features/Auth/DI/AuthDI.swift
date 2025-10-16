enum AuthDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(TokenStoreProtocol.self) { container in
            TokenStore(
                storage: try await container.resolve(KeychainStorageProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(AuthServiceProtocol.self) { container in
            AuthService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(AuthManagerProtocol.self) { container in
            AuthManager(
                authService: try await container.resolve(AuthServiceProtocol.self),
                tokenStore: try await container.resolve(TokenStoreProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(AuthorizationInterceptor.self) { container in
            AuthorizationInterceptor(
                authManager: try await container.resolve(AuthManagerProtocol.self)
            )
        }
    }
}
