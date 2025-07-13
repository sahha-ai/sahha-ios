protocol SensorManager: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func resumeSensors() async
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
}

final class SensorManagerImpl: SensorManager {
    private let store: SensorStore
    private let hkManager: HKManager
    private let logger: Logger
    
    init(store: SensorStore, hkManager: HKManager, logger: Logger) {
        self.store = store
        self.hkManager = hkManager
        self.logger = logger
    }
    
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let currentSensors = await store.getSensors()
        let sensorsToDisable = currentSensors.subtracting(sensors)
        
        await disableSensors(sensorsToDisable)
        await store.setSensors(sensors)
        
        let objectTypes = Set(sensors.compactMap(\.hkObjectType))
        
        guard !objectTypes.isEmpty else { return }
        
        try await hkManager.startSensors(objectTypes)
    }
    
    func resumeSensors() async {
        let sensors = await store.getSensors()
        let objectTypes = Set(sensors.compactMap(\.hkObjectType))
        guard !objectTypes.isEmpty else { return }
        do {
            try await hkManager.startSensors(objectTypes)
        } catch {
            logger.error("Failed to resume sensors: \(error.localizedDescription)")
        }
    }
    
    private func disableSensors(_ sensors: Set<SahhaSensor>) async {
        let objectTypes = Set(sensors.compactMap(\.hkObjectType))
        
        guard !objectTypes.isEmpty else { return }
        
        do {
            try await hkManager.stopSensors(objectTypes)
        } catch {
            logger.error("Error disabling sensors: \(error.localizedDescription)")
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        let objectTypes = Set(sensors.compactMap(\.hkObjectType))
        
        guard !objectTypes.isEmpty else { return .pending }
        
        let status = try await hkManager.getSensorStatus(objectTypes)
        
        switch status {
        case .unnecessary:
            return .enabled
        default:
            return .pending
        }
    }
}
