import Foundation

final actor UserDefaultsSensorStorage: SensorStoring {
    private let storage: UserDefaultsStoring
    private let key = StorageKeys.UserDefaults.enabledSensorsKey
    private let logger: ErrorLogger

    init(storage: UserDefaultsStoring = UserDefaultsStorage(), logger: ErrorLogger) {
        self.storage = storage
        self.logger = logger
    }

    func saveSensors(_ sensors: Set<SahhaSensor>) async {
        do {
            try await storage.setCodable(sensors, forKey: key)
        } catch {
            logger.sdkError("Failed to encode enabled sensors", error: error)
        }
    }

    func loadSensors() async -> Set<SahhaSensor> {
        do {
            return try await storage.getCodable(Set<SahhaSensor>.self, forKey: key) ?? []
        } catch {
            logger.sdkError("Failed to decode enabled sensors", error: error)
            return []
        }
    }

    func clearSensors() async {
        await storage.delete(forKey: key)
    }
    
    func dispose() async {
        await clearSensors()
    }
}
