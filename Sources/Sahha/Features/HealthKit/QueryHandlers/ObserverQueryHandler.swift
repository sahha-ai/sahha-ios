import HealthKit

protocol ObserverQueryHandlerProtocol: Actor {
    func startObserver(for sampleType: HKSampleType) async
    func stopObserver(for sampleType: HKSampleType) async
    func stopAllObservers() async
}

final actor ObserverQueryHandler: ObserverQueryHandlerProtocol {
    private let healthStore: HKHealthStore
    private let logger: LoggerProtocol
    private let anchorQueryHandler: AnchorQueryHandlerProtocol

    private var activeObservers: [String: HKObserverQuery] = [:]

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: LoggerProtocol,
        anchorQueryHandler: AnchorQueryHandlerProtocol
    ) {
        self.healthStore = healthStore
        self.logger = logger
        self.anchorQueryHandler = anchorQueryHandler
    }

    func startObserver(for sampleType: HKSampleType) async {
        let identifier = sampleType.identifier
        
        if activeObservers[identifier] != nil {
            logger.warning("Already observing \(identifier), skipping start observer call.")
            return
        }
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] query, completionHandler, error in
            guard let self = self else {
                completionHandler()
                return
            }
            if let error = error {
                self.logger.error("Observer query failed for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
                completionHandler()
                return
            }
            Task {
                await self.anchorQueryHandler.executeAnchorQuery(for: sampleType)
            }
            completionHandler()
        }

        healthStore.execute(query)
        activeObservers[identifier] = query
        logger.info("Started observer for \(sampleType.identifier)")
    }

    func stopObserver(for sampleType: HKSampleType) async {
        let identifier = sampleType.identifier
        if let query = activeObservers[identifier] {
            healthStore.stop(query)
            activeObservers.removeValue(forKey: identifier)
            logger.info("Stopped observer for \(identifier)")
        }
    }
    
    func stopAllObservers() async {
        for (_, query) in activeObservers {
            healthStore.stop(query)
        }
        activeObservers.removeAll()
        logger.info("Stopped all observers")
    }
}
