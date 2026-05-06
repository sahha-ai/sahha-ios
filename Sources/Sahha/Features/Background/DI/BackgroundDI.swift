import Foundation

final class BackgroundDI {
    static func registerDependencies(container: DIContainer, settings: SahhaSettings) async {
        await container.register(BackgroundCoordinatorProtocol.self) { container in
            BackgroundCoordinator(
                healthKitManager: try await container.resolve(HealthKitManagerProtocol.self),
                dataLogPipeline: try await container.resolve(DataLogPipelineProtocol.self),
                profileIdProvider: try await container.resolve(ProfileIdProviderProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                enableMotionTrigger: settings.enableMotionTrigger
            )
        }
    }
}
