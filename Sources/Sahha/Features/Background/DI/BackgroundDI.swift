import Foundation

final class BackgroundDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(BackgroundCoordinatorProtocol.self) { container in
            BackgroundCoordinator(
                healthKitManager: try await container.resolve(HealthKitManagerProtocol.self),
                dataLogPipeline: try await container.resolve(DataLogPipelineProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }
}
