import HealthKit

protocol HKAnchorQueryHandler: Actor {
    func executeQuery(for sampleType: HKSampleType) async
}

final actor HKAnchorQueryHandlerImpl: HKAnchorQueryHandler {
    private let batchLimit = 1000
    private let healthStore: HKHealthStore
    private let anchorStore: HKAnchorStore
    private let logger: Logger
    private let processor: DataLogProcessor
    private let normaliser: NormalisingEngine<HKSample, DataLog>

    private var activeAnchors: Set<String> = []

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        anchorStore: HKAnchorStore,
        logger: Logger,
        processor: DataLogProcessor,
        normaliser: NormalisingEngine<HKSample, DataLog>
    ) {
        self.healthStore = healthStore
        self.anchorStore = anchorStore
        self.logger = logger
        self.processor = processor
        self.normaliser = normaliser
    }

    func executeQuery(for sampleType: HKSampleType) async {
        let id = sampleType.identifier
        guard activeAnchors.insert(id).inserted else { return }
        defer { activeAnchors.remove(id) }
        
        var anchor = await anchorStore.getAnchor(for: id)
        
        while true {
            do {
                let (samples, nextAnchor) = try await anchoredBatch(for: sampleType, anchor: anchor)
                
                guard !samples.isEmpty else {
                    break
                }
                
                let logs = samples.flatMap(normaliser.normalise)
                await processor.enqueue(logs)
                
                if let nextAnchor = nextAnchor {
                    anchor = nextAnchor
                    await anchorStore.saveAnchor(for: id, anchor: nextAnchor)
                }
            } catch {
                logger.error("\(id) anchor query failed: \(error.localizedDescription)")
                break
            }
        }
    }

    private func anchoredBatch(
        for sampleType: HKSampleType,
        anchor: HKQueryAnchor?
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: nil,
                anchor: anchor,
                limit: batchLimit
            ) { _, samples, _, nextAnchor, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let batch = samples ?? []
                    continuation.resume(returning: (batch, nextAnchor))
                }
            }
            healthStore.execute(query)
        }
    }
}
