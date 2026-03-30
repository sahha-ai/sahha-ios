enum HealthKitDI {
    static func registerDependencies(container: DIContainer) async {
        await registerQueries(container: container)
        await registerPermissions(container: container)
        await registerDemographics(container: container)
        await registerObservers(container: container)
        await registerNormalisers(container: container)
        await registerStores(container: container)
        await registerCoordinators(container: container)
        await registerUploaders(container: container)
        await registerManager(container: container)
        await registerLifecycleListeners(container: container)
    }

    // MARK: - Queries
    private static func registerQueries(container: DIContainer) async {
        await container.register(HealthKitAnchorQueryServiceProtocol.self) { _ in
            HealthKitAnchorQueryService()
        }
        await container.register(HealthKitSampleQueryServiceProtocol.self) { _ in
            HealthKitSampleQueryService()
        }
        await container.register(HealthKitStatsQueryServiceProtocol.self) { _ in
            HealthKitStatsQueryService()
        }
    }

    // MARK: - Permissions
    private static func registerPermissions(container: DIContainer) async {
        await container.register(HealthKitPermissionsServiceProtocol.self) { _ in
            HealthKitPermissionsService()
        }
    }

    // MARK: - Demographics
    private static func registerDemographics(container: DIContainer) async {
        await container.register(HealthKitDemographicServiceProtocol.self) { _ in
            HealthKitDemographicService()
        }
    }

    // MARK: - Observers
    private static func registerObservers(container: DIContainer) async {
        await container.register(HealthKitObserverServiceProtocol.self) { container in
            HealthKitObserverService(
                permissions: try await container.resolve(HealthKitPermissionsServiceProtocol.self),
                observerStore: try await container.resolve(HealthKitObserverStoreProtocol.self),
                circuitBreaker: try? await container.resolve(CircuitBreaker.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }

    // MARK: - Normalisers
    private static func registerNormalisers(container: DIContainer) async {
        await container.register(HKSampleToDataLogNormaliserProtocol.self) { _ in
            HKSampleToDataLogNormaliserRegistry()
        }
        await container.register(FallbackHKSampleToDataLogNormaliser.self) { _ in
            FallbackHKSampleToDataLogNormaliser()
        }
        await container.register(HKSampleToSahhaSampleNormaliserProtocol.self) { _ in
            HKSampleToSahhaSampleNormaliserRegistry()
        }
        await container.register(FallbackHKSampleToSahhaSampleNormaliser.self) { _ in
            FallbackHKSampleToSahhaSampleNormaliser()
        }
        await container.register(HKSampleToTagNormaliserProtocol.self) { _ in
            HKSampleToTagNormaliserRegistry()
        }
    }

    // MARK: - Stores
    private static func registerStores(container: DIContainer) async {
        await container.register(HealthKitAnchorStoreProtocol.self) { container in
            HealthKitAnchorStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
        await container.register(HealthKitAnchorDateStoreProtocol.self) { container in
            HealthKitAnchorDateStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
        await container.register(HealthKitObserverStoreProtocol.self) { _ in
            HealthKitObserverStore()
        }
    }

    // MARK: - Coordinators
    private static func registerCoordinators(container: DIContainer) async {
        await container.register(HealthKitDataLogCoordinatorProtocol.self) { container in
            HealthKitDataLogCoordinator(
                observerService: try await container.resolve(HealthKitObserverServiceProtocol.self),
                anchorQueryService: try await container.resolve(HealthKitAnchorQueryServiceProtocol.self),
                anchorStore: try await container.resolve(HealthKitAnchorStoreProtocol.self),
                normaliser: try await container.resolve(HKSampleToDataLogNormaliserProtocol.self),
                dataLogPipeline: try await container.resolve(DataLogPipelineProtocol.self),
                circuitBreaker: try? await container.resolve(CircuitBreaker.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(HealthKitSahhaSampleCoordinatorProtocol.self) { container in
            HealthKitSahhaSampleCoordinator(
                sampleQueryService: try await container.resolve(HealthKitSampleQueryServiceProtocol.self),
                permissions: try await container.resolve(HealthKitPermissionsServiceProtocol.self),
                normaliser: try await container.resolve(HKSampleToSahhaSampleNormaliserProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(HealthKitTagCoordinatorProtocol.self) { container in
            HealthKitTagCoordinator(
                observerService: try await container.resolve(HealthKitObserverServiceProtocol.self),
                anchorQueryService: try await container.resolve(HealthKitAnchorQueryServiceProtocol.self),
                anchorStore: try await container.resolve(HealthKitAnchorStoreProtocol.self),
                normaliser: try await container.resolve(HKSampleToTagNormaliserProtocol.self),
                tagPipeline: try await container.resolve(TagPipelineProtocol.self),
                circuitBreaker: try? await container.resolve(CircuitBreaker.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
        await container.register(HealthKitSahhaStatCoordinatorProtocol.self) { container in
            HealthKitSahhaStatCoordinator(
                statsQueryService: try await container.resolve(HealthKitStatsQueryServiceProtocol.self),
                sampleQueryService: try await container.resolve(HealthKitSampleQueryServiceProtocol.self),
                permissions: try await container.resolve(HealthKitPermissionsServiceProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }
    
    // MARK: - Uploaders
    private static func registerUploaders(container: DIContainer) async {
        await container.register(HealthKitActivitySummaryUploaderProtocol.self) { container in
            HealthKitActivitySummaryUploader(
                permissionsService: try await container.resolve(HealthKitPermissionsServiceProtocol.self),
                anchorStore: try await container.resolve(HealthKitAnchorDateStoreProtocol.self),
                queryService: try await container.resolve(HealthKitAnchorQueryServiceProtocol.self),
                normaliserRegistry: try await container.resolve(HKSampleToDataLogNormaliserProtocol.self),
                dataLogPipeline: try await container.resolve(DataLogPipelineProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }

    // MARK: - Manager
    private static func registerManager(container: DIContainer) async {
        await container.register(HealthKitManagerProtocol.self) { container in
            HealthKitManager(
                permissions: try await container.resolve(HealthKitPermissionsServiceProtocol.self),
                sensorStore: try await container.resolve(SensorStoreProtocol.self),
                dataLogCoordinator: try await container.resolve(HealthKitDataLogCoordinatorProtocol.self),
                tagCoordinator: try await container.resolve(HealthKitTagCoordinatorProtocol.self),
                statCoordinator: try await container.resolve(HealthKitSahhaStatCoordinatorProtocol.self),
                sampleCoordinator: try await container.resolve(HealthKitSahhaSampleCoordinatorProtocol.self),
                demographicService: try await container.resolve(HealthKitDemographicServiceProtocol.self),
                activitySummaryUploader: try await container.resolve(HealthKitActivitySummaryUploaderProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self)
            )
        }
    }
    
    // MARK: - Lifecycle Listeners
    private static func registerLifecycleListeners(container: DIContainer) async {
        await container.register(PostInsightsLifecycleListener.self) { container in
            PostInsightsLifecycleListener(
                healthKitManager: try await container.resolve(HealthKitManagerProtocol.self)
            )
        }
    }
}
