final class SensorManager: SensorManaging {
    private let sensorStore: SensorStoring
    private let healthKitService: HealthKitProviding
    
    init(sensorStore: SensorStoring, healthKitService: HealthKitProviding) {
        self.sensorStore = sensorStore
        self.healthKitService = healthKitService
    }
    
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let previouslyEnabled = await sensorStore.loadSensors()
        
        await sensorStore.saveSensors(sensors)
        
        try await healthKitService.enableSensors(sensors)
        
        let toDisable = previouslyEnabled.subtracting(sensors)
        if !toDisable.isEmpty {
            try await healthKitService.disableSensors(toDisable)
        }
    }
    
    func resumeSensors() async throws {
        let enabledSensors = await sensorStore.loadSensors()
        try await healthKitService.resumeSensors(enabledSensors)
    }
    
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        try await healthKitService.getSensorStatus(sensors)
    }
}
