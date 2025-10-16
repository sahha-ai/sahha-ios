enum NetworkingDI {
    static func registerDependencies(container: DIContainer, settings: SahhaSettings) async {
        await container.register(APIInterceptorStoreProtocol.self) { _ in
            APIInterceptorStore()
        }
        await container.register(APIClientProtocol.self) { container in
            APIClient(
                baseURL: settings.environment.baseURL,
                interceptorStore: try await container.resolve(APIInterceptorStoreProtocol.self),
            )
        }
    }
}
