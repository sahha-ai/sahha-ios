import HealthKit

actor HealthKitDataLogCoordinator: HealthKitDataLogCoordinatorProtocol, Disposable {
    private let observerService: HealthKitObserverServiceProtocol
    private let anchorQueryService: HealthKitAnchorQueryServiceProtocol
    private let anchorStore: HealthKitAnchorStoreProtocol
    private let normaliser: HKSampleToDataLogNormaliserProtocol
    private let dataLogPipeline: DataLogPipelineProtocol
    private let circuitBreaker: CircuitBreaker?
    private let logger: ErrorLoggerProtocol
    private let queryLimit: Int

    private var observerTasks: [Task<Void, Never>] = []
    private let queryTasks = SingleTaskActorMap<String, SensorQueryResult>()

    init(
        observerService: HealthKitObserverServiceProtocol,
        anchorQueryService: HealthKitAnchorQueryServiceProtocol,
        anchorStore: HealthKitAnchorStoreProtocol,
        normaliser: HKSampleToDataLogNormaliserProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
        circuitBreaker: CircuitBreaker? = nil,
        logger: ErrorLoggerProtocol,
        queryLimit: Int = 500
    ) {
        self.observerService = observerService
        self.anchorQueryService = anchorQueryService
        self.anchorStore = anchorStore
        self.normaliser = normaliser
        self.dataLogPipeline = dataLogPipeline
        self.circuitBreaker = circuitBreaker
        self.logger = logger
        self.queryLimit = queryLimit
    }

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        try await observerService.startObservers(for: sensors) { [weak self] sensor, sampleType in
            await self?.launchTrackedQuery(for: sensor, sampleType: sampleType)
        }
        try await observerService.enableBackgroundDelivery(for: sensors)
    }

    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        for sensor in sensors {
            await queryTasks.cancel(for: sensor.rawValue)
        }
        try await observerService.stopObservers(for: sensors)
        try await observerService.disableBackgroundDelivery(for: sensors)
    }

    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] {
        var results: [SensorQueryResult] = []
        for sensor in sensors {
            guard let sampleType = sensor.hkSampleType else {
                let result = SensorQueryResult(
                    sensor: sensor,
                    status: .failed,
                    samplesFetched: 0,
                    logsProduced: 0,
                    anchorUpdated: false,
                    message: "Sensor has no HKSampleType",
                    errorDescription: nil
                )
                results.append(result)
                continue
            }
            let result = await runSensorQuery(for: sensor, sampleType: sampleType)
            results.append(result)
        }
        return results
    }

    private func launchTrackedQuery(for sensor: SahhaSensor, sampleType: HKSampleType) async {
        let task = Task { [weak self] in
            if let self {
                _ = await self.runSensorQuery(for: sensor, sampleType: sampleType)
            }
        }
        observerTasks.append(task)
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

            // Check circuit breaker before running expensive query
            if let circuitBreaker = self.circuitBreaker {
                let isHealthy = await circuitBreaker.isHealthy()
                if !isHealthy {
                    let (state, _) = await circuitBreaker.getState()
                    let message = "Circuit breaker is \(state)"
                    print("[HealthKitDataLogCoordinator] Skipping query for \(sensor.rawValue) - \(message)")
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
            var totalLogs = 0
            var anchorUpdated = false
            var message: String?
            var errorDescription: String?
            var status: SensorQueryResult.Status = .success

            do {
                var anchor = try await anchorStore.loadAnchor(for: sensor)

                while !Task.isCancelled {
                    let (samples, newAnchor) = try await anchorQueryService.runAnchorQuery(
                        for: sampleType,
                        anchor: anchor,
                        limit: queryLimit
                    )
                    guard !samples.isEmpty else { break }

                    totalSamples += samples.count

                    let dataLogs = samples.flatMap { self.normaliser.normalise($0) }
                    totalLogs += dataLogs.count

                    guard !Task.isCancelled else { break }
                    await self.dataLogPipeline.ingest(dataLogs)

                    if let newAnchor {
                        anchor = newAnchor
                        try await anchorStore.saveAnchor(newAnchor, for: sensor)
                        anchorUpdated = true
                    }
                }
            } catch {
                status = .failed
                errorDescription = error.localizedDescription
                self.logger.postError(error)
            }

            if status == .success {
                if totalSamples == 0 {
                    status = .noSamples
                    message = "No new samples for sensor"
                } else {
                    message = "Fetched \(totalSamples) samples, produced \(totalLogs) logs"
                }
            }

            return SensorQueryResult(
                sensor: sensor,
                status: status,
                samplesFetched: totalSamples,
                logsProduced: totalLogs,
                anchorUpdated: anchorUpdated,
                message: message,
                errorDescription: errorDescription
            )
        }
    }

    func dispose() async {
        for task in observerTasks {
            task.cancel()
        }
        observerTasks.removeAll()
        await queryTasks.cancelAll()
    }
}
