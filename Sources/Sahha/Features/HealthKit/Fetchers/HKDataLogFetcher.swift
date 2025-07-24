import HealthKit

final actor HKDataLogFetcher: HKDataLogFetching {
    private let healthStore: HKHealthStore
    private let observer: HKObserverProviding
    private let anchorStore: HKAnchorStoring
    private let pipeline: DataLogPipelineProviding
    private let permissions: HKPermissionsProviding
    private let queryLimit: Int
    private let logger: ErrorLogger

    private var activeTasks: [SahhaSensor: Task<Void, Never>] = [:]

    init(
        healthStore: HKHealthStore = .init(),
        observer: HKObserverProviding,
        anchorStore: HKAnchorStoring,
        pipeline: DataLogPipelineProviding,
        permissions: HKPermissionsProviding,
        queryLimit: Int = 10_000,
        logger: ErrorLogger
    ) {
        self.healthStore = healthStore
        self.observer = observer
        self.anchorStore = anchorStore
        self.pipeline = pipeline
        self.permissions = permissions
        self.queryLimit = queryLimit
        self.logger = logger
    }

    func start(for sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }

        guard try await permissions.hasPermission(for: sensor) else {
            throw HealthKitError.permissionDenied(sensor)
        }

        try await observer.startObserving(sensor: sensor) { [weak self] sensor in
            Task { await self?.launchFetchTask(for: sensor) }
        }
    }

    func stop(for sensor: SahhaSensor) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthKitUnavailable
        }

        do {
            try await observer.stopObserving(sensor: sensor)
        } catch {
            logger.sdkError("Failed to stop observer for \(sensor)", error: error)
        }

        do {
            try await observer.disableBackgroundDelivery(for: sensor)
        } catch {
            logger.sdkError("Failed to disable background delivery for \(sensor)", error: error)
        }
    }

    // Manage only one background fetch task per sensor
    private func launchFetchTask(for sensor: SahhaSensor) {
        // If a task is already running, just return (don't launch another)
        guard activeTasks[sensor] == nil else { return }
        let task = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                try await self.fetchAndProcess(for: sensor)
            } catch is CancellationError {
                // Just exit quietly; cancellation is expected on shutdown
            } catch {
                self.logger.sdkError("Error while fetching data logs for \(sensor)", error: error)
            }
        }
        activeTasks[sensor] = task
    }

    private func fetchAndProcess(for sensor: SahhaSensor) async throws {
        defer { self.activeTasks.removeValue(forKey: sensor) }

        guard let sampleType = sensor.hkSampleType else {
            throw HealthKitError.invalidSensor(sensor)
        }

        guard try await permissions.hasPermission(for: sensor) else {
            throw HealthKitError.permissionDenied(sensor)
        }

        var anchor: HKQueryAnchor?
        do {
            anchor = try await anchorStore.loadAnchor(for: sensor.rawValue)
        } catch {
            logger.sdkError("Failed to get anchor for \(sensor)", error: error)
            anchor = nil
        }

        while true {
            let (samples, newAnchor) = try await HKAsyncAnchorQuery.execute(
                for: sampleType,
                anchor: anchor,
                limit: queryLimit,
                using: healthStore
            )

            guard samples.notEmpty else { break }

            let dataLogs = await ConcurrentBatchProcessor.run(
                items: samples,
                batchSize: 200,
                maxConcurrentBatches: 4
            ) { batch in
                batch.flatMap { $0.toDataLog() }
            }

            do {
                try await pipeline.ingest(dataLogs)
            } catch is CancellationError {
                break
            } catch {
                logger.sdkError("Failed to ingest data logs", error: error)
                break
            }

            if let newAnchor {
                anchor = newAnchor
                do {
                    try await anchorStore.saveAnchor(newAnchor, for: sensor.rawValue)
                } catch {
                    logger.sdkError("Failed to save anchor for \(sensor)", error: error)
                }
            }
        }
    }

    func dispose() async {
        for (_, task) in activeTasks { task.cancel() }
        for (_, task) in activeTasks { await task.value }
        activeTasks.removeAll()

        do {
            try await observer.stopAllObservers()
        } catch {
            logger.sdkError("Failed to stop all observers", error: error)
        }

        do {
            try await observer.disableAllBackgroundDelivery()
        } catch {
            logger.sdkError("Failed to disable all background delivery", error: error)
        }
    }
}
