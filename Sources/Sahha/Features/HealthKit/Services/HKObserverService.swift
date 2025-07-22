import HealthKit

final actor HKObserverService: HKObserverProviding {
    private let healthStore: HKHealthStore
    private let logger: ErrorLogger
    
    private var activeObservers: [SahhaSensor: HKObserverQuery] = [:]
    
    init(healthStore: HKHealthStore = .init(), logger: ErrorLogger) {
        self.healthStore = healthStore
        self.logger = logger
    }
    
    func startObserving(sensor: SahhaSensor, handler: @escaping @Sendable (SahhaSensor) -> Void) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        guard let sampleType = sensor.hkSampleType else {
            throw HealthKitError.invalidSensor(sensor)
        }
        
        // TODO: Check if weak self is needed here
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
            // Signal HealthKit before doing work
            completion()
            
            guard let self else { return }
            
            if let error = error {
                self.logger.sdkError("Error observing \(sensor)", error: error)
                return
            }
            
            handler(sensor)
        }
        
        healthStore.execute(query)
        activeObservers[sensor] = query
    }

    func stopObserving(sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        if let query = activeObservers.removeValue(forKey: sensor) {
            healthStore.stop(query)
        }
    }

    func enableBackgroundDelivery(for sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        guard let sampleType = sensor.hkSampleType else {
            throw HealthKitError.invalidSensor(sensor)
        }
        
        try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
    }
    
    func disableBackgroundDelivery(for sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        guard let sampleType = sensor.hkSampleType else {
            throw HealthKitError.invalidSensor(sensor)
        }
        
        try await healthStore.disableBackgroundDelivery(for: sampleType)
    }
    
    func stopAllObservers() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        for (_, query) in activeObservers {
            healthStore.stop(query)
        }
        activeObservers.removeAll()
    }
    
    func disableAllBackgroundDelivery() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        try await healthStore.disableAllBackgroundDelivery()
    }
}
