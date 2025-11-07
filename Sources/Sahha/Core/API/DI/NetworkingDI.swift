enum NetworkingDI {
    static func registerDependencies(container: DIContainer, settings: SahhaSettings) async {
        // Register interceptor store
        await container.register(APIInterceptorStoreProtocol.self) { _ in
            APIInterceptorStore()
        }
        
        // Register background session delegate for upload tasks
        await container.register(BackgroundSessionDelegate.self) { container in
            BackgroundSessionDelegate(
                circuitBreaker: try? await container.resolve(CircuitBreaker.self),
                logger: try? await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        
        // Register standard API client for regular requests (auth, scores, etc.)
        await container.register(APIClientProtocol.self) { container in
            APIClient(
                baseURL: settings.environment.baseURL,
                session: URLSessionFactory.createOptimizedSession(),
                interceptorStore: try await container.resolve(APIInterceptorStoreProtocol.self)
            )
        }
        
        // Register background API client for future use
        // Note: Background sessions don't support async/await completion handlers
        // They require delegate-based upload tasks, which needs a different implementation
        // For now, uploads use the optimized default session with waitsForConnectivity
        await container.register(BackgroundAPIClient.self) { container in
            let delegate = try await container.resolve(BackgroundSessionDelegate.self)
            let session = URLSessionFactory.createBackgroundSession(
                identifier: "ai.sahha.datalog.upload",
                delegate: delegate
            )
            return APIClient(
                baseURL: settings.environment.baseURL,
                session: session,
                interceptorStore: try await container.resolve(APIInterceptorStoreProtocol.self)
            )
        }
    }
}

/// Type alias for background upload API client
typealias BackgroundAPIClient = APIClient
