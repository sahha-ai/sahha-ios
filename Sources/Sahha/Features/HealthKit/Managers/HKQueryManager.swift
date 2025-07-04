import HealthKit

final actor HKQueryManager: HKQueryManagerProtocol {
    private let logger: LoggerProtocol
    private let healthStore: HKHealthStore
    private let anchorPersistence = AnchorPersistence()
    private let normalisers: [String: any HKNormaliser]
    private let processor: DataLogProcessorProtocol

    private var anchors: [String: HKQueryAnchor]
    private var observerQueries: [String: HKObserverQuery] = [:]
    private var isDisposed = false

    init(
        logger: LoggerProtocol,
        healthStore: HKHealthStore = HKHealthStore(),
        normalisers: [String: any HKNormaliser],
        processor: DataLogProcessorProtocol
    ) {
        self.logger = logger
        self.healthStore = healthStore
        self.normalisers = normalisers
        self.processor = processor
        self.anchors = anchorPersistence.loadAnchors()
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
            logger.warning("Already observing \(identifier), skipping.")
            return
        }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
            if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                self.logger.warning("Authorization denied for \(identifier), stopping observer query.")
                Task {
                    await self.stopObserverQuery(for: sampleType)
                }
            } else if let error = error {
                self.logger.error("Observer query failed for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
            } else {
                Task {
                    await self.runAnchorQuery(for: sampleType)
                }
            }
            completionHandler()
        }

        observerQueries[identifier] = query
        healthStore.execute(query)
        logger.info("Started observer query for \(identifier)")
    }

    func stopObserverQuery(for type: HKObjectType) async {
        let identifier = type.identifier
        if let query = observerQueries[identifier] {
            healthStore.stop(query)
            observerQueries.removeValue(forKey: identifier)
            logger.info("Stopped observer query for \(identifier)")
        }
    }

    func stopAllAndClear() async throws {
        for (_, query) in observerQueries {
            healthStore.stop(query)
        }
        observerQueries.removeAll()
        anchors.removeAll()
        anchorPersistence.deleteAnchors()
        isDisposed = true
    }

    func querySamples(for type: HKSampleType, startDateTime: Date, endDateTime: Date) async throws -> [HKSample] {
        let identifier = type.identifier

        let samples: [HKSample] = try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: startDateTime, end: endDateTime)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error as? HKError {
                    self.logger.error("Sample query error for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
                    switch error.code {
                    case .errorAuthorizationDenied:
                        continuation.resume(throwing: HealthKitError.permissionDenied)
                    default:
                        continuation.resume(throwing: HealthKitError.queryFailed(sensor: identifier))
                    }
                } else if let error = error {
                    self.logger.error("Sample query failed for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
                    continuation.resume(throwing: HealthKitError.queryFailed(sensor: identifier))
                } else {
                    continuation.resume(returning: samples ?? [])
                }
            }

            healthStore.execute(query)
        }

        return samples
    }

    func queryStats(for type: HKObjectType, startDateTime: Date, endDateTime: Date) async -> [HKStatistics] {
        fatalError("Not implemented")
    }

    private func runAnchorQuery(for type: HKSampleType) async {
        guard !isDisposed else { return }

        let identifier = type.identifier
        let anchor = anchors[identifier]

        while await processor.isAcceptingData() && !isDisposed {
            let (samples, newAnchor): ([HKSample], HKQueryAnchor?) = await withCheckedContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: type,
                    predicate: nil,
                    anchor: anchor,
                    limit: 5000
                ) { _, samples, _, newAnchor, error in
                    if let error = error as? HKError, error.code == .errorAuthorizationDenied {
                        self.logger.warning("Authorization denied for \(identifier), stopping observer query.")
                        Task {
                            await self.stopObserverQuery(for: type)
                        }
                    } else if let error = error {
                        self.logger.error("Anchored query failed for \(identifier): \(error.localizedDescription)", file: #file, function: #function)
                    }

                    self.logger.info("Received \(samples?.count ?? 0) samples for \(identifier)")
                    continuation.resume(returning: (samples ?? [], newAnchor))
                }

                healthStore.execute(query)
            }

            if samples.isEmpty {
                break
            }

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
