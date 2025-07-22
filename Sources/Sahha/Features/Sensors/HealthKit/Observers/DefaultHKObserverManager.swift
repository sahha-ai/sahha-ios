import HealthKit

final actor DefaultHKObserverManager: HKObserverManager {
    private let healthStore: HKHealthStore
    private var activeObservers: [SahhaSensor: HKObserverQuery] = [:]

    init(healthStore: HKHealthStore = .init()) {
        self.healthStore = healthStore
    }
    
    func startObserving(sensors: Set<SahhaSensor>, handler: @escaping ObserverHandlerFn) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }
        
        for sensor in sensors {
            guard
                activeObservers[sensor] == nil,
                let sampleType = sensor.hkObjectType as? HKSampleType
            else { continue }
            
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self, sensor] _, completion, error in
                // Signal HealthKit before doing work
                completion()
                
                guard self != nil, error == nil else {
                    print("HK observing failed for \(sensor): \(String(describing: error))")
                    return
                }
                
                Task { try await handler(sensor) }
            }
            
            do {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
            } catch {
                print("Failed to enable background delivery for \(sensor): \(error)")
            }
            
            healthStore.execute(query)
            activeObservers[sensor] = query
        }
    }

    func stopObserving(sensors: Set<SahhaSensor>) async {
        for sensor in sensors {
            if let sampleType = sensor.hkObjectType as? HKSampleType {
                do {
                    try await healthStore.disableBackgroundDelivery(for: sampleType)
                } catch {
                    print("Failed to disable background delivery for \(sensor): \(error)")
                }
            }
            if let query = activeObservers.removeValue(forKey: sensor) {
                healthStore.stop(query)
            }
        }
    }

    func stopObservingAll() async {
        do {
            try await healthStore.disableAllBackgroundDelivery()
        } catch {
            print("Failed to disable all background delivery: \(error)")
        }
        
        for (_, query) in activeObservers {
            healthStore.stop(query)
        }
        activeObservers.removeAll()
    }

}
