import HealthKit

final actor HKManager: HKManagerProtocol {
    private let logger: LoggerProtocol
    private let permissionManager: HKPermissionManagerProtocol
    private let queryManager: HKQueryManagerProtocol

    init(logger: LoggerProtocol, permissionManager: HKPermissionManagerProtocol, queryManager: HKQueryManagerProtocol) {
        self.logger = logger
        self.permissionManager = permissionManager
        self.queryManager = queryManager
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Sensors")
        }
        let sampleTypes = sensors.compactMap { HKSensorMapper.objectType(for: $0) }
        guard !sampleTypes.isEmpty else {
            throw HealthKitError.noMappedSensors
        }
        let sampleTypeSet = Set(sampleTypes)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sampleType in sampleTypeSet {
                group.addTask {
                    do {
                        try await self.queryManager.enableBackgroundDelivery(for: sampleType)
                    } catch {
                        let sensor = HKSensorMapper.sahhaSensor(for: sampleType)
                        self.logger.error("Failed to enable background delivery for \(sensor?.rawValue ?? "unknown sensor"): \(error)")
                    }
                    await self.queryManager.startObserverQuery(for: sampleType)
                }
            }
            for try await _ in group {}
        }
    }

    func disableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let sampleTypes = sensors.compactMap { HKSensorMapper.objectType(for: $0) }
        let sampleTypeSet = Set(sampleTypes)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sampleType in sampleTypeSet {
                group.addTask {
                    do {
                        try await self.queryManager.disableBackgroundDelivery(for: sampleType)
                    } catch {
                        let sensor = HKSensorMapper.sahhaSensor(for: sampleType)
                        self.logger.error("Failed to disable background delivery for \(sensor?.rawValue ?? "unknown"): \(error)")
                    }
                    await self.queryManager.stopObserverQuery(for: sampleType)
                }
            }
            for try await _ in group {}
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard !sensors.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Sensors")
        }
        let sampleTypes = sensors.compactMap { HKSensorMapper.objectType(for: $0) }
        guard !sampleTypes.isEmpty else {
            throw HealthKitError.noMappedSensors
        }
        let sampleTypeSet = Set(sampleTypes)

        let status = try await permissionManager.getPermissionStatus(for: sampleTypeSet)

        switch status {
        case .unnecessary:
            return .enabled
        default:
            return .pending
        }
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [HKSample] {
        guard let sampleType = HKSensorMapper.objectType(for: sensor) as? HKSampleType else {
            throw HealthKitError.unknownType
        }

        let status = permissionManager.getPermissionStatus(for: sampleType)

        switch status {
        case .sharingAuthorized:
            return try await queryManager.querySamples(for: sampleType, startDateTime: startDateTime, endDateTime: endDateTime)
        default:
            throw HealthKitError.permissionDenied
        }
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [HKStatistics] {
        guard let sampleType = HKSensorMapper.objectType(for: sensor) else {
            throw HealthKitError.unknownType
        }

        let status = permissionManager.getPermissionStatus(for: sampleType)

        switch status {
        case .sharingAuthorized:
            return try await queryManager.queryStats(for: sampleType, startDateTime: startDateTime, endDateTime: endDateTime)
        default:
            throw HealthKitError.permissionDenied
        }
    }

    func dispose() async throws {
        try await queryManager.stopAllAndClear()
    }
}
