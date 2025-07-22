import HealthKit

final actor DataLogFetcher {
    private let healthStore: HKHealthStore
    private let anchorStore: HKAnchorStore
    private let processor: any BatchProcessor<DataLog>
    private let logger: Logger

    private var activeQueries: Set<SahhaSensor> = []

    init(healthStore: HKHealthStore = .init(), anchorStore: HKAnchorStore, processor: any BatchProcessor<DataLog>, logger: Logger) {
        self.healthStore = healthStore
        self.anchorStore = anchorStore
        self.processor = processor
        self.logger = logger
    }

    func fetchAndProcessSamples(for sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.error("HealthKit not available on this device")
            throw HealthKitError.healthKitUnavailable
        }

        guard !activeQueries.contains(sensor), let sampleType = sensor.hkObjectType as? HKSampleType else {
            logger.warning("Query for sensor \(sensor.rawValue) is already active or sampleType is nil.")
            return
        }
        activeQueries.insert(sensor)

        defer { activeQueries.remove(sensor) }

        do {
            let startTime = Date()
            var totalSamples = 0

            var anchor = try await anchorStore.loadAnchor(for: sensor.rawValue)

            while true {
                let (samples, newAnchor) = try await HKAnchoredObjectQuery.anchoredQuery(
                    for: sampleType,
                    anchor: anchor,
                    limit: 1_000,
                    using: healthStore
                )
                
                totalSamples += samples.count
                print("Fetched \(samples.count) samples for \(sensor.rawValue), running total: \(totalSamples)")

                if samples.isEmpty {
                    let elapsed = Date().timeIntervalSince(startTime)
                    logger.info(
                        "No more samples for sensor: \(sensor.rawValue), exiting fetch loop. Total samples: \(totalSamples), time: \(elapsed) seconds"
                    )
                    logger.info("No more samples for sensor: \(sensor.rawValue), exiting fetch loop.")
                    break
                }

                let dataLogs = DataLogNormaliser.normalise(samples, sensor: sensor)
//                try await processor.enqueue(dataLogs, for: sensor.rawValue)
//                await processor.waitTilProcessed(for: sensor.rawValue)

                if let newAnchor {
                    try await anchorStore.saveAnchor(newAnchor, for: sensor.rawValue)
                    anchor = newAnchor
                }
            }
        } catch {
            logger.error("Error fetching or processing samples for sensor: \(sensor.rawValue): \(error)")
            throw error
        }
    }
}
