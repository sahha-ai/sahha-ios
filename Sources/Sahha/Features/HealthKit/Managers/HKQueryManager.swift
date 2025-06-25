import HealthKit

final actor HKQueryManager: HKQueryManagerProtocol {
    private let healthStore: HKHealthStore
    private let persistence = AnchorPersistence()
    private let normalisers: [String: any HKNormaliser]
    private let processor: any DataLogProcessorProtocol

    private var anchors: [String: HKQueryAnchor]
    private var observerQueries: [String: HKObserverQuery] = [:]

    init(healthStore: HKHealthStore = HKHealthStore(), normalisers: [String: any HKNormaliser], processor: any DataLogProcessorProtocol) {
        self.healthStore = healthStore
        self.normalisers = normalisers
        self.processor = processor
        self.anchors = persistence.loadAnchors()
    }

    func enableBackgroundDelivery(for type: HKObjectType) async throws {
        try await healthStore.enableBackgroundDelivery(for: type, frequency: .immediate)
    }

    func disableBackgroundDelivery(for type: HKObjectType) async throws {
        try await healthStore.disableBackgroundDelivery(for: type)
    }

    func startObserverQuery(for type: HKObjectType) async {
        guard let sampleType = type as? HKSampleType else { return }
        let identifier = sampleType.identifier

        if observerQueries[identifier] != nil {
            print("Already observing \(identifier), skipping.")
            return
        }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
            if let error = error {
                print("Observer query failed for \(identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }

            Task {
                await self.runAnchorQuery(for: sampleType)
            }

            completionHandler()
        }

        observerQueries[identifier] = query
        healthStore.execute(query)
        print("Started observer query for \(identifier)")
    }

    func stopObserverQuery(for type: HKObjectType) async {
        let identifier = type.identifier
        if let query = observerQueries[identifier] {
            healthStore.stop(query)
            observerQueries.removeValue(forKey: identifier)
            print("Stopped observer query for \(identifier)")
        }
    }

    private func runAnchorQuery(for type: HKSampleType) async {
        let identifier = type.identifier
        let anchor = anchors[identifier]

        let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: 500
            ) { _, samples, _, newAnchor, error in
                if let error = error {
                    print("Anchored query failed for \(type.identifier): \(error.localizedDescription)")
                    continuation.resume(returning: ([], nil))
                    return
                }
                
                print("Received \(samples?.count ?? 0) samples for \(identifier)")

                continuation.resume(returning: (samples ?? [], newAnchor))
            }

            healthStore.execute(query)
        }

        let normalisedSamples = await samples.concurrentFlatMap {
            if let normaliser = self.normalisers[identifier] {
                return normaliser.normalise(sample: $0)
            }
            return nil
        }
        
        let silencedError = newAnchor
        
        print("Normalised \(normalisedSamples.count) samples for \(identifier)")

        try? await processor.process(normalisedSamples)
    }
}

private struct AnchorPersistence {
    private let key = Constants.UserDefaultsKeys.healthKitAnchors

    func loadAnchors() -> [String: HKQueryAnchor] {
        guard let dataDict = UserDefaults.standard.dictionary(forKey: key) as? [String: Data] else {
            return [:]
        }
        return dataDict.compactMapValues { data in
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        }
    }

    func saveAnchor(for identifier: String, anchor: HKQueryAnchor) {
        var anchorDataDict = (UserDefaults.standard.dictionary(forKey: key) as? [String: Data]) ?? [:]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            anchorDataDict[identifier] = data
            UserDefaults.standard.set(anchorDataDict, forKey: key)
        }
    }
}
