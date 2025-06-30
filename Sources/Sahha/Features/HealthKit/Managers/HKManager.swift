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
        let sampleTypes = sensors.compactMap { SensorMapper.objectType(for: $0) }
        let sampleTypeSet = Set(sampleTypes)

        try await permissionManager.requestPermissions(for: sampleTypeSet)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sampleType in sampleTypeSet {
                group.addTask {
                    do {
                        try await self.queryManager.enableBackgroundDelivery(for: sampleType)
                    } catch {
                        let sensor = SensorMapper.sensor(for: sampleType)
                        self.logger.error("Failed to enable background delivery for \(sensor?.rawValue ?? "unknown sensor"): \(error)")
                    }
                    await self.queryManager.startObserverQuery(for: sampleType)
                }
            }
            for try await _ in group {}
        }
    }

    func disableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let sampleTypes = sensors.compactMap { SensorMapper.objectType(for: $0) }
        let sampleTypeSet = Set(sampleTypes)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sampleType in sampleTypeSet {
                group.addTask {
                    do {
                        try await self.queryManager.disableBackgroundDelivery(for: sampleType)
                    } catch {
                        let sensor = SensorMapper.sensor(for: sampleType)
                        self.logger.error("Failed to disable background delivery for \(sensor?.rawValue ?? "unknown"): \(error)")
                    }
                    await self.queryManager.stopObserverQuery(for: sampleType)
                }
            }
            for try await _ in group {}
        }
    }

    func dispose() async throws {
        try await queryManager.stopAllAndClear()
    }
}
