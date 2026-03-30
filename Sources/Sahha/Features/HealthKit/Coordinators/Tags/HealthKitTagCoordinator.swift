import HealthKit

enum HealthKitTagCoordinatorError: LocalizedError {
    case queryTimeout(sensor: SahhaSensor, seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .queryTimeout(sensor, seconds):
            return "HealthKit anchor query timed out for sensor \(sensor.rawValue) after \(Int(seconds))s"
        }
    }
}

actor HealthKitTagCoordinator: HealthKitTagCoordinatorProtocol, Disposable {
    private let observerService: HealthKitObserverServiceProtocol
    private let anchorQueryService: HealthKitAnchorQueryServiceProtocol
    private let anchorStore: HealthKitAnchorStoreProtocol
    private let normaliser: HKSampleToTagNormaliserProtocol
    private let tagPipeline: TagPipelineProtocol
    private let circuitBreaker: CircuitBreaker?
    private let logger: ErrorLoggerProtocol
    private let queryLimit: Int
    private let queryTimeout: TimeInterval

    private let queryTasks = SingleTaskActorMap<String, SensorQueryResult>()

    init(
        observerService: HealthKitObserverServiceProtocol,
        anchorQueryService: HealthKitAnchorQueryServiceProtocol,
        anchorStore: HealthKitAnchorStoreProtocol,
        normaliser: HKSampleToTagNormaliserProtocol,
        tagPipeline: TagPipelineProtocol,
        circuitBreaker: CircuitBreaker? = nil,
        logger: ErrorLoggerProtocol,
        queryLimit: Int = 500,
        queryTimeout: TimeInterval = 30
    ) {
        self.observerService = observerService
        self.anchorQueryService = anchorQueryService
        self.anchorStore = anchorStore
        self.normaliser = normaliser
        self.tagPipeline = tagPipeline
        self.circuitBreaker = circuitBreaker
        self.logger = logger
        self.queryLimit = queryLimit
        self.queryTimeout = queryTimeout
    }

    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {
        try await observerService.startObservers(for: sensors) { [weak self] sensor, sampleType in
            guard let self else {
                Sahha.log("[HealthKitTagCoordinator] Observer fired but coordinator was deallocated for sensor: \(sensor.rawValue)")
                return
            }
            let result = await self.runSensorQuery(for: sensor, sampleType: sampleType)
            Sahha.log("[HealthKitTagCoordinator] Background observer query completed for \(sensor.rawValue): \(result.status.rawValue), samples: \(result.samplesFetched), tags: \(result.logsProduced)")

            if result.status == .failed, let error = result.errorDescription {
                Sahha.log("[HealthKitTagCoordinator] Background query error for \(sensor.rawValue): \(error)")
                Sahha.scheduleBackgroundRefreshIfNeeded(timeInterval: 300)
            } else if result.logsProduced > 0 {
                Sahha.scheduleBackgroundRefreshIfNeeded(timeInterval: 900)
            }
        }
        try await observerService.enableBackgroundDelivery(for: sensors)
    }

    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            await queryTasks.cancel(for: sensor.rawValue)
        }
        try await observerService.stopObservers(for: sensors)
        try await observerService.disableBackgroundDelivery(for: sensors)
    }

    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] {
        await withTaskGroup(of: SensorQueryResult.self) { group in
            for sensor in sensors {
                if let sampleType = sensor.hkSampleType {
                    group.addTask { [self] in
                        await self.runSensorQuery(for: sensor, sampleType: sampleType)
                    }
                } else {
                    group.addTask {
                        SensorQueryResult(
                            sensor: sensor,
                            status: .failed,
                            samplesFetched: 0,
                            logsProduced: 0,
                            anchorUpdated: false,
                            message: "Sensor has no HKSampleType",
                            errorDescription: nil
                        )
                    }
                }
            }

            var results: [SensorQueryResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func runSensorQuery(for sensor: SahhaSensor, sampleType: HKSampleType) async -> SensorQueryResult {
        let key = sensor.rawValue

        return await queryTasks.run(for: key) { [weak self] in
            guard let self else {
                return SensorQueryResult(
                    sensor: sensor,
                    status: .failed,
                    samplesFetched: 0,
                    logsProduced: 0,
                    anchorUpdated: false,
                    message: "Coordinator deallocated",
                    errorDescription: nil
                )
            }

            if let circuitBreaker = self.circuitBreaker {
                let isHealthy = await circuitBreaker.isHealthy()
                if !isHealthy {
                    let (state, _) = await circuitBreaker.getState()
                    let message = "Circuit breaker is \(state)"
                    Sahha.log("[HealthKitTagCoordinator] Skipping query for \(sensor.rawValue) - \(message)")
                    return SensorQueryResult(
                        sensor: sensor,
                        status: .skippedCircuitOpen,
                        samplesFetched: 0,
                        logsProduced: 0,
                        anchorUpdated: false,
                        message: message,
                        errorDescription: nil
                    )
                }
            }

            var totalSamples = 0
            var totalTags = 0
            var anchorUpdated = false
            var message: String?
            var errorDescription: String?
            var status: SensorQueryResult.Status = .success

            do {
                var anchor = try await anchorStore.loadAnchor(for: sensor)

                var startDate: Date?
                var endDate: Date?

                if anchor == nil {
                    let now = Date()
                    let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 24 * 3600)
                    startDate = thirtyDaysAgo
                    endDate = now
                    Sahha.log("[HealthKitTagCoordinator] Initial sync for \(sensor.rawValue). Limiting to 30 days history.")
                }

                while !Task.isCancelled {
                    let (samples, newAnchor) = try await runAnchorQueryWithTimeout(
                        for: sampleType,
                        startDate: startDate,
                        endDate: endDate,
                        anchor: anchor,
                        limit: queryLimit,
                        sensor: sensor
                    )
                    guard !samples.isEmpty else { break }

                    totalSamples += samples.count

                    let tags = samples.flatMap { self.normaliser.normalise($0) }
                    totalTags += tags.count

                    guard !Task.isCancelled else { break }
                    await self.tagPipeline.ingest(tags)

                    if let newAnchor {
                        do {
                            try await anchorStore.saveAnchor(newAnchor, for: sensor)
                            anchor = newAnchor
                            anchorUpdated = true
                        } catch {
                        }
                    }
                }
            } catch {
                status = .failed
                errorDescription = error.localizedDescription
            }

            if status == .success {
                if totalSamples == 0 {
                    status = .noSamples
                    message = "No new samples for sensor"
                } else {
                    message = "Fetched \(totalSamples) samples, produced \(totalTags) tags"
                }
            }

            return SensorQueryResult(
                sensor: sensor,
                status: status,
                samplesFetched: totalSamples,
                logsProduced: totalTags,
                anchorUpdated: anchorUpdated,
                message: message,
                errorDescription: errorDescription
            )
        }
    }

    func dispose() async {
        await queryTasks.cancelAll()
    }

    private func runAnchorQueryWithTimeout(
        for sampleType: HKSampleType,
        startDate: Date? = nil,
        endDate: Date? = nil,
        anchor: HKQueryAnchor?,
        limit: Int,
        sensor: SahhaSensor
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        try await withThrowingTaskGroup(of: ([HKSample], HKQueryAnchor?).self) { group in
            group.addTask { [self] in
                var predicate: NSPredicate?
                if let startDate, let endDate {
                    predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
                }

                return try await self.anchorQueryService.runAnchorQuery(
                    for: sampleType,
                    predicate: predicate,
                    anchor: anchor,
                    limit: limit
                )
            }

            let timeoutNanoseconds = UInt64(max(queryTimeout, 0.1) * 1_000_000_000)
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw HealthKitTagCoordinatorError.queryTimeout(sensor: sensor, seconds: self.queryTimeout)
            }

            guard let result = try await group.next() else {
                throw HealthKitTagCoordinatorError.queryTimeout(sensor: sensor, seconds: self.queryTimeout)
            }

            group.cancelAll()
            return result
        }
    }
}
