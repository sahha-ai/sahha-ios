import HealthKit

protocol HealthKitManagerProtocol: Sendable, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors(_ sensors: Set<SahhaSensor>) async throws
    func disableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}

final actor HealthKitManager: HealthKitManagerProtocol {
    private let healthStore: HKHealthStore
    private let logger: LoggerProtocol
    private let observerQueryHandler: ObserverQueryHandlerProtocol
    private let sampleQueryHandler: SampleQueryHandlerProtocol
    private let statisticsQueryHandler: StatisticsQueryHandlerProtocol

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: LoggerProtocol,
        observerQueryHandler: ObserverQueryHandlerProtocol,
        sampleQueryHandler: SampleQueryHandlerProtocol,
        statisticsQueryHandler: StatisticsQueryHandlerProtocol
    ) {
        self.healthStore = healthStore
        self.logger = logger
        self.observerQueryHandler = observerQueryHandler
        self.sampleQueryHandler = sampleQueryHandler
        self.statisticsQueryHandler = statisticsQueryHandler
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else { return }
        
        let objectTypes = sensors.compactMap(\.hkObjectType)
        
        guard !objectTypes.isEmpty else {
            throw HealthKitError.noMappedSensors
        }
        
        try await healthStore.statusForAuthorizationRequest(toShare: [], read: Set(objectTypes))
        try await resumeSensors(sensors)
    }

    func resumeSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else { return }
        
        let objectTypes = sensors.compactMap { $0.hkObjectType }
        
        guard !objectTypes.isEmpty else {
            throw HealthKitError.noMappedSensors
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for objectType in objectTypes {
                group.addTask {
                    do {
                        let status = try await self.healthStore.statusForAuthorizationRequest(toShare: [], read: [objectType])
                        if status != .unnecessary {
                            self.logger.warning("Permission not granted for \(objectType.identifier). Skipping observer start.")
                            return
                        }
                    } catch {
                        self.logger.error("Failed to check permission status for \(objectType.identifier): \(error.localizedDescription)", file: #file, function: #function)
                    }
                    if let sampleType = objectType as? HKSampleType {
                        await self.observerQueryHandler.startObserver(for: sampleType)
                    }
                    do {
                        try await self.healthStore.enableBackgroundDelivery(for: objectType, frequency: .immediate)
                        self.logger.info("Background delivery enabled for \(objectType.identifier)")
                    } catch {
                        self.logger.error("Failed to enable background delivery for \(objectType.identifier): \(error.localizedDescription)", file: #file, function: #function)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    func disableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let objectTypes = sensors.compactMap { $0.hkObjectType }
        guard !objectTypes.isEmpty else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for objectType in objectTypes {
                group.addTask {
                    if let sampleType = objectType as? HKSampleType {
                        await self.observerQueryHandler.stopObserver(for: sampleType)
                    }
                    do {
                        try await self.healthStore.disableBackgroundDelivery(for: objectType)
                        self.logger.info("Background delivery disabled for \(objectType.identifier)")
                    } catch {
                        self.logger.error("Failed to disable background delivery for \(objectType.identifier): \(error.localizedDescription)", file: #file, function: #function)
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        let objectTypes = sensors.compactMap(\.hkObjectType)
        guard !objectTypes.isEmpty else {
            throw HealthKitError.noMappedSensors
        }

        let status = try await healthStore.statusForAuthorizationRequest(toShare: [], read: Set(objectTypes))

        switch status {
        case .unnecessary:
            return .enabled
        default:
            return .pending
        }
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard let sampleType = sensor.hkObjectType as? HKSampleType else {
            throw HealthKitError.unknownType
        }
        return try await sampleQueryHandler.executeSampleQuery(for: sampleType)
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard let sampleType = sensor.hkObjectType as? HKSampleType else {
            throw HealthKitError.unknownType
        }
        return try await statisticsQueryHandler.executeStatisticsQuery(for: sampleType)
    }

    func dispose() async throws {
        try await healthStore.disableAllBackgroundDelivery()
        await observerQueryHandler.stopAllObservers()
    }
}
