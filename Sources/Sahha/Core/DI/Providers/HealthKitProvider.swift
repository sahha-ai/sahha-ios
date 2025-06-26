import HealthKit

struct HealthKitProvider: ServiceProvider {
    func registerServices(in container: DIContainer) async {
        await container.registerSingleton(HKManagerProtocol.self) { container in
            let permissionManager = HKPermissionManager()
            let processor = try await container.resolve((any DataLogProcessorProtocol).self)
            let normalisers: [String: any HKNormaliser] = [
                HKQuantityTypeIdentifier.heartRate.rawValue: HKHeartRateNormaliser(),
                HKQuantityTypeIdentifier.stepCount.rawValue: HKStepCountNormaliser(),
                HKCategoryTypeIdentifier.sleepAnalysis.rawValue: HKSleepAnalysisNormaliser(),
                HKWorkoutTypeIdentifier: HKWorkoutNormaliser(),
            ]
            let queryManager = HKQueryManager(normalisers: normalisers, processor: processor)
            return HKManager(permissionManager: permissionManager, queryManager: queryManager)
        }
    }
}
