import HealthKit

protocol SensorManagerProtocol: Actor, DisposableAsync {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensor: Set<SahhaSensor>) async throws -> SahhaSensorStatus
}

actor SensorManager: SensorManagerProtocol {
    private let storage: any UserDefaultsStorageProtocol<Set<SahhaSensor>>
    private let healthKitManager: HealthKitManagerProtocol
    
    private var cachedSensors: Set<SahhaSensor> = []
    
    init(storage: any UserDefaultsStorageProtocol<Set<SahhaSensor>>, healthKitManager: HealthKitManagerProtocol) {
        self.storage = storage
        self.healthKitManager = healthKitManager
        self.cachedSensors = storage.get() ?? []
    }
    
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let sampleTypes = sensors.compactMap { $0.hkSampleType }
        if sampleTypes.isEmpty { return }
        
        try await healthKitManager.requestPermissions(for: Set(sampleTypes))
        
        let currentSensors = cachedSensors
        let updatedSensors = currentSensors.union(sensors)
        cachedSensors = updatedSensors
        storage.set(updatedSensors)
        
        for sampleType in sampleTypes {
            do {
                try await healthKitManager.enableBackgroundDelivery(for: sampleType)
                await healthKitManager.startObserverQuery(for: sampleType)
            } catch {
                print("Failed to enable background delivery for \(sampleType): \(error)")
            }
        }
    }
    
    func getSensorStatus(_ sensor: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        return .pending
    }
    
    // TODO
    func dispose() async {}
}
