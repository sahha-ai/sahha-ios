import HealthKit

protocol HKObserverQueryHandler: Actor {
    func startObserver(for sampleType: HKSampleType) async
    func stopObserver(for sampleType: HKSampleType) async
    func stopAllObservers() async
}

final actor HKObserverQueryHandlerImpl: HKObserverQueryHandler {
    private let healthStore: HKHealthStore
    private let logger: Logger
    private let anchorQueryHandler: HKAnchorQueryHandler

    private var activeObservers: [String: HKObserverQuery] = [:]

    init(healthStore: HKHealthStore = HKHealthStore(), logger: Logger, anchorQueryHandler: HKAnchorQueryHandler) {
        self.healthStore = healthStore
        self.logger = logger
        self.anchorQueryHandler = anchorQueryHandler
    }

    func startObserver(for sampleType: HKSampleType) async {
        let id = sampleType.identifier
        if activeObservers[id] != nil { return }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            [weak self] (_, completion, error) in
            if let error {
                self?.logger.error("Error in observer query: \(error.localizedDescription)")
                completion()
                return
            }
            Task { await self?.anchorQueryHandler.executeQuery(for: sampleType) }
            completion()
        }

        do {
            try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
        } catch {
            logger.error("Error enabling background delivery: \(error)")
        }

        activeObservers[id] = query
        healthStore.execute(query)
    }

    func stopObserver(for sampleType: HKSampleType) async {
        let id = sampleType.identifier
        if let query = activeObservers[id] {
            healthStore.stop(query)
            activeObservers.removeValue(forKey: id)
        }
        do {
            try await healthStore.disableBackgroundDelivery(for: sampleType)
        } catch {
            logger.error("Error disabling background delivery: \(error)")
        }
    }

    func stopAllObservers() async {
        for (_, query) in activeObservers {
            healthStore.stop(query)
        }
        activeObservers.removeAll()
        do {
            try await healthStore.disableAllBackgroundDelivery()
        } catch {
            logger.error("Error disabling background delivery: \(error)")
        }
    }
}
