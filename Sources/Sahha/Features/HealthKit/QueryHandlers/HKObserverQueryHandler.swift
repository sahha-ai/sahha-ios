import HealthKit

protocol HKObserverQueryHandler: Sendable, Disposable {
    func startObserver(for sampleType: HKSampleType) async
    func stopObserver(for sampleType: HKSampleType) async
}

final class HKObserverQueryHandlerImpl: HKObserverQueryHandler {
    private let healthStore: HKHealthStore
    private let logger: Logger
    private let observerStore = ObserverStore()
    private let eventHandler: HKObserverEventHandler

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: Logger,
        eventHandler: HKObserverEventHandler
    ) {
        self.healthStore = healthStore
        self.logger = logger
        self.eventHandler = eventHandler
    }

    func startObserver(for sampleType: HKSampleType) async {
        let id = sampleType.identifier

        if await observerStore.activeObservers[id] != nil {
            return
        }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            [weak self] (_, completion, error) in
            guard let self else {
                completion()
                return
            }

            if let error {
                self.logger.error("Error in observer query: \(error.localizedDescription)")
                completion()
                return
            }

            Task {
                await self.eventHandler.handleObserverEvent(for: sampleType)
            }

            completion()
        }

        do {
            try await healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate)
        } catch {
            logger.error("Failed to enable background delivery: \(error.localizedDescription)")
        }

        healthStore.execute(query)

        await observerStore.addObserver(query, for: sampleType)
    }

    func stopObserver(for sampleType: HKSampleType) async {
        if let query = await observerStore.removeObserver(for: sampleType) {
            healthStore.stop(query)
        }
        do {
            try await healthStore.disableBackgroundDelivery(for: sampleType)
        } catch {
            logger.error("Failed to disable background delivery: \(error.localizedDescription)")
        }
    }

    func dispose() async {
        let observers = await observerStore.activeObservers.values
        for query in observers {
            healthStore.stop(query)
        }
        do {
            try await healthStore.disableAllBackgroundDelivery()
        } catch {
            logger.error("Failed to disable all background delivery: \(error.localizedDescription)")
        }
        await observerStore.removeAllObservers()
    }
}

private final actor ObserverStore {
    var activeObservers: [String: HKObserverQuery] = [:]
    
    func addObserver(_ observer: HKObserverQuery, for objectType: HKObjectType) {
        activeObservers.updateValue(observer, forKey: objectType.description)
    }

    func removeObserver(for objectType: HKObjectType)-> HKObserverQuery? {
        activeObservers.removeValue(forKey: objectType.description)
    }

    func removeAllObservers() {
        activeObservers.removeAll()
    }
}

