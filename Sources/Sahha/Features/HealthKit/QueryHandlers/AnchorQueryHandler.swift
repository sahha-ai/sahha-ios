import HealthKit

protocol AnchorQueryHandlerProtocol: Actor {
    func executeAnchorQuery(for type: HKSampleType) async
}

final actor AnchorQueryHandler: AnchorQueryHandlerProtocol {
    private let healthStore: HKHealthStore
    private let logger: LoggerProtocol
    private let normalisers: [String: any HKNormaliser]
    private let processor: DataLogProcessorProtocol
    private let anchorPersistence = AnchorPersistence()
    
    private var anchors: [String: HKQueryAnchor]
    
    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: LoggerProtocol,
        normalisers: [String: any HKNormaliser],
        processor: DataLogProcessorProtocol,
    ) {
        self.healthStore = healthStore
        self.logger = logger
        self.normalisers = normalisers
        self.processor = processor
        self.anchors = anchorPersistence.loadAnchors()
    }
    
    func executeAnchorQuery(for type: HKSampleType) async {
        let identifier = type.identifier
        
        while await processor.isAcceptingData() {
            let anchor = anchors[identifier]
            
            let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: nil,
                    anchor: anchor,
                    limit: 50_000
                ) { _, samples, _, newAnchor, error in
                    if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                        self.logger.warning("Authorization denied for \(identifier).")
                    } else if let error = error {
                        self.logger.error("Anchored query failed for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
                    }

                    self.logger.info("Received \(samples?.count ?? 0) samples for \(identifier)")
                    continuation.resume(returning: (samples ?? [], newAnchor))
                }
                healthStore.execute(query)
            }

            guard !samples.isEmpty else { break }

            let normalisedSamples = await samples.concurrentFlatMap {
                if let normaliser = self.normalisers[identifier] {
                    return normaliser.normalise(sample: $0)
                }
                return nil
            }
            
            if !normalisedSamples.isEmpty {
                await processor.process(normalisedSamples)
                
                if let newAnchor {
                    self.anchors[identifier] = newAnchor
                    self.anchorPersistence.saveAnchor(for: identifier, anchor: newAnchor)
                }
            }
        }
    }
}

private struct AnchorPersistence {
    private let key = Constants.UserDefaultsKeys.healthKitAnchors
    private let userDefaults = UserDefaults.standard

    func loadAnchors() -> [String: HKQueryAnchor] {
        guard let dataDict = userDefaults.dictionary(forKey: key) as? [String: Data] else {
            return [:]
        }
        return dataDict.compactMapValues { data in
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        }
    }

    func saveAnchor(for identifier: String, anchor: HKQueryAnchor) {
        var anchorDataDict = (userDefaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            anchorDataDict[identifier] = data
            UserDefaults.standard.set(anchorDataDict, forKey: key)
        }
    }

    func deleteAnchors() {
        userDefaults.removeObject(forKey: key)
    }
}
