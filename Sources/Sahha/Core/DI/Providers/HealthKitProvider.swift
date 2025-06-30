import HealthKit

struct HealthKitProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(HKManagerProtocol.self) { container in
            let logger = try await container.resolve(LoggerProtocol.self)
            let permissionManager = HKPermissionManager()
            let processor = try await container.resolve((any DataLogProcessorProtocol).self)
            let normalisers: [String: any HKNormaliser] = [
                HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateNormaliser(),
                HKQuantityTypeIdentifier.stepCount.rawValue: HKStepCountNormaliser(),
                HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisNormaliser(),
                HKWorkoutTypeIdentifier: HKWorkoutNormaliser(),
            ]
            let queryManager = HKQueryManager(logger: logger, normalisers: normalisers, processor: processor)
            return HKManager(logger: logger, permissionManager: permissionManager, queryManager: queryManager)
        }
    }
}
