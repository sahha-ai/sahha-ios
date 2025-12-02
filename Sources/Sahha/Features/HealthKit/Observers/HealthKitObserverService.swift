import HealthKit

final class HealthKitObserverService: HealthKitObserverServiceProtocol {
    private let healthStore: HKHealthStore
    private let permissions: HealthKitPermissionsServiceProtocol
    private let observerStore: HealthKitObserverStoreProtocol
    private let circuitBreaker: CircuitBreaker?
    private let logger: ErrorLoggerProtocol
    
    init(
        healthStore: HKHealthStore = .init(),
        permissions: HealthKitPermissionsServiceProtocol,
        observerStore: HealthKitObserverStoreProtocol,
        circuitBreaker: CircuitBreaker? = nil,
        logger: ErrorLoggerProtocol
    ) {
        self.healthStore = healthStore
        self.permissions = permissions
        self.observerStore = observerStore
        self.circuitBreaker = circuitBreaker
        self.logger = logger
    }
    
    func startObservers(for sensors: Set<SahhaSensor>, handler: @escaping HealthKitObserverHandler) async throws {
        for sensor in sensors {
            try await startObserver(for: sensor, handler: handler)
        }
    }
    
    private func startObserver(for sensor: SahhaSensor, handler: @escaping HealthKitObserverHandler) async throws {
        if let sampleType = sensor.hkSampleType, try await permissions.hasPermissions(for: sensor) {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
                if let error {
                    self?.logger.postError(error)
                    completion()
                } else {
                    // Check circuit breaker state before triggering query
                    let wrappedCompletion = SendableCompletion(run: completion)
                    
                    Task {
                        defer { wrappedCompletion.run() }
                        
                        guard let self else { return }
                        
                        // If circuit breaker exists, check if system is healthy
                        if let circuitBreaker = self.circuitBreaker {
                            let isHealthy = await circuitBreaker.isHealthy()
                            if !isHealthy {
                                let (state, _) = await circuitBreaker.getState()
                                print("[HealthKitObserver] Skipping query for \(sensor.rawValue) - circuit breaker is \(state)")
                                return
                            }
                        }
                        
                        // Circuit is healthy or doesn't exist - proceed with query
                        await handler(sensor, sampleType)
                    }
                }
            }
            await observerStore.addObserver(query, for: sensor)
            healthStore.execute(query)
        }
    }
    
    private struct SendableCompletion: @unchecked Sendable {
        let run: () -> Void
    }
    
    func stopObservers(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            try await stopObserver(for: sensor)
        }
    }

    private func stopObserver(for sensor: SahhaSensor) async throws {
        if let query = await observerStore.removeObserver(for: sensor) {
            healthStore.stop(query)
        }
    }
    
    func enableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            if let sampleType = sensor.hkSampleType {
                try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
            }
        }
    }

    func disableBackgroundDelivery(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            if let sampleType = sensor.hkSampleType {
                try await healthStore.disableBackgroundDelivery(for: sampleType)
            }
        }
    }
    
    func dispose() async {
        await stopAllObservers()
        await disableAllBackgroundDeliveries()
    }

    private func stopAllObservers() async {
        for query in await observerStore.removeAllObservers() {
            healthStore.stop(query)
        }
    }

    private func disableAllBackgroundDeliveries() async {
        do {
            try await healthStore.disableAllBackgroundDelivery()
        } catch {
            logger.postError(error)
        }
    }
}


