import HealthKit

protocol HKManager: Sendable {
    func startSensors(_ types: Set<HKObjectType>) async throws
    func resumeSensors(_ types: Set<HKObjectType>) async throws
    func stopSensors(_ types: Set<HKObjectType>) async throws
    func getSensorStatus(_ types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}

final class HKManagerImpl: HKManager, Disposable {
    private let permissionHandler: HKPermissionHandler
    private let observerQueryHandler: HKObserverQueryHandler
    private let sampleQueryHandler: HKSampleQueryHandler
    private let statsQueryHandler: HKStatisticsQueryHandler

    init(
        permissionHandler: HKPermissionHandler,
        observerQueryHandler: HKObserverQueryHandler,
        sampleQueryHandler: HKSampleQueryHandler,
        statsQueryHandler: HKStatisticsQueryHandler
    ) {
        self.permissionHandler = permissionHandler
        self.observerQueryHandler = observerQueryHandler
        self.sampleQueryHandler = sampleQueryHandler
        self.statsQueryHandler = statsQueryHandler
    }

    func startSensors(_ types: Set<HKObjectType>) async throws {
        try await permissionHandler.requestReadPermissions(for: types)
        try await resumeSensors(types)
    }
    
    func resumeSensors(_ types: Set<HKObjectType>) async throws {
        await withTaskGroup(of: Void.self) { group in
            for type in types {
                group.addTask {
                    guard let sample = type as? HKSampleType,
                        await self.permissionHandler.hasReadPermission(for: sample)
                    else { return }

                    await self.observerQueryHandler.startObserver(for: sample)
                }
            }
        }
    }

    func stopSensors(_ types: Set<HKObjectType>) async throws {
        await withTaskGroup(of: Void.self) { group in
            for type in types {
                group.addTask {
                    guard let sample = type as? HKSampleType else { return }
                    await self.observerQueryHandler.stopObserver(for: sample)
                }
            }
        }
    }

    func getSensorStatus(_ types: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        try await permissionHandler.checkReadPermissions(for: types)
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard let sampleType = sensor.hkObjectType as? HKSampleType else {
            throw SensorError.noHealthKitMapping(sensor)
        }
        
        guard await permissionHandler.hasReadPermission(for: sampleType) else {
            throw SensorError.permissionDenied(sensor)
        }
        
        let _ = try await sampleQueryHandler.executeQuery(for: sampleType, startDateTime: startDateTime, endDateTime: endDateTime)
        
        return [] // TODO
    }
    
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard let quantityType = sensor.hkObjectType as? HKQuantityType else {
            throw SensorError.noHealthKitMapping(sensor)
        }
        
        guard await permissionHandler.hasReadPermission(for: quantityType) else {
            throw SensorError.permissionDenied(sensor)
        }
        
        let stats = try await statsQueryHandler.executeQuery(for: quantityType, startDateTime: startDateTime, endDateTime: endDateTime)
        return stats.compactMap(SahhaStat.create)
    }
    
    func dispose() async {
        await observerQueryHandler.stopAllObservers()
    }
}
