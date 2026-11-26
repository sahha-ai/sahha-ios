import HealthKit

actor HealthKitTagCoordinator: HealthKitTagCoordinatorProtocol, Disposable {
    private let observerService: HealthKitObserverServiceProtocol
    private let anchorStore: HealthKitAnchorStoreProtocol
    private let normaliser: HKSampleToTagNormaliserProtocol
    private let profileIdProvider: ProfileIdProviderProtocol
    private let tagPipeline: TagPipelineProtocol
    private let circuitBreaker: CircuitBreaker?
    private let logger: ErrorLoggerProtocol
    private let pager: AnchoredQueryPager

    private let queryTasks = SingleTaskActorMap<String, SensorQueryResult>()

    /// - Parameter querySlots: Anchored-query slots. Production shares one pool between
    ///   the data-log and tag coordinators (see `HealthKitDI`); the default is private.
    init(
        observerService: HealthKitObserverServiceProtocol,
        anchorQueryService: HealthKitAnchorQueryServiceProtocol,
        anchorStore: HealthKitAnchorStoreProtocol,
        normaliser: HKSampleToTagNormaliserProtocol,
        profileIdProvider: ProfileIdProviderProtocol,
        tagPipeline: TagPipelineProtocol,
        circuitBreaker: CircuitBreaker? = nil,
        logger: ErrorLoggerProtocol,
        queryLimit: Int = 500,
        queryTimeout: TimeInterval = 30,
        querySlots: AsyncSemaphore = AsyncSemaphore(value: AnchoredQueryPager.defaultConcurrencyLimit),
        appStateProvider: ApplicationStateProviding? = nil
    ) {
        self.observerService = observerService
        self.anchorStore = anchorStore
        self.normaliser = normaliser
        self.profileIdProvider = profileIdProvider
        self.tagPipeline = tagPipeline
        self.circuitBreaker = circuitBreaker
        self.logger = logger
        self.pager = AnchoredQueryPager(
            logLabel: "HealthKitTagCoordinator",
            service: anchorQueryService,
            slots: querySlots,
            fullPageSize: queryLimit,
            timeout: queryTimeout,
            appStateProvider: appStateProvider
        )
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

                // Reject data older than 30 days on EVERY run, not just the first.
                // Anchored queries return any sample newly written to HealthKit since the
                // last anchor regardless of the sample's actual date, so a source that
                // backfills history (a new Apple Watch pairing, a device restore, a
                // third-party app sync) would otherwise surface months- or years-old data.
                let now = Date()
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now.addingTimeInterval(-30 * 24 * 3600)

                // On the FIRST run (no anchor), also bound the query itself to the last 30
                // days so HealthKit filters server-side rather than loading years of
                // history into memory just to discard it.
                var startDate: Date?
                var endDate: Date?

                if anchor == nil {
                    startDate = cutoffDate
                    endDate = now
                    Sahha.log("[HealthKitTagCoordinator] Initial sync for \(sensor.rawValue). Limiting to 30 days history.")
                }

                var pagesCompleted = 0
                while !Task.isCancelled {
                    let (samples, newAnchor) = try await runAnchorQueryWithTimeout(
                        for: sampleType,
                        startDate: startDate,
                        endDate: endDate,
                        anchor: anchor,
                        sensor: sensor,
                        pagesCompleted: pagesCompleted
                    )
                    guard !samples.isEmpty else {
                        // Caught up: a sensor whose pages shrank after a timeout goes
                        // back to full-size pages.
                        await self.pager.sensorCaughtUp(sensor)
                        break
                    }
                    pagesCompleted += 1

                    totalSamples += samples.count

                    // Drop samples older than the cutoff before normalising. The raw
                    // `samples` array still drives pagination and the anchor still advances
                    // below, so backdated data is skipped permanently and never re-fetched.
                    let recentSamples = samples.filter { $0.endDate >= cutoffDate }

                    let profileId = self.profileIdProvider.profileId()
                    let tags = recentSamples.flatMap { self.normaliser.normalise($0, profileId: profileId) }
                    totalTags += tags.count

                    guard !Task.isCancelled else { break }
                    await self.tagPipeline.ingest(tags)

                    if let newAnchor {
                        do {
                            try await anchorStore.saveAnchor(newAnchor, for: sensor)
                            anchor = newAnchor
                            anchorUpdated = true
                        } catch {
                            // An unsaved anchor cannot advance, so the next pass
                            // would fetch this identical page again, forever. Stop
                            // this run; the next trigger resumes from the last
                            // saved anchor.
                            self.logger.postError(error)
                            break
                        }
                    }
                }
            } catch is CancellationError {
                // Collection was stopped mid-query (stopTagCollection or dispose):
                // not a failure, and whatever was ingested stands.
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

    /// One page through the shared pager. Timeouts are posted here, so the report
    /// names this coordinator.
    private func runAnchorQueryWithTimeout(
        for sampleType: HKSampleType,
        startDate: Date?,
        endDate: Date?,
        anchor: HKQueryAnchor?,
        sensor: SahhaSensor,
        pagesCompleted: Int
    ) async throws -> ([HKSample], HKQueryAnchor?) {
        do {
            return try await pager.fetchPage(
                for: sensor,
                sampleType: sampleType,
                startDate: startDate,
                endDate: endDate,
                anchor: anchor,
                pagesCompleted: pagesCompleted
            )
        } catch let timeout as AnchoredQueryTimeoutError {
            // Two call sites on purpose: the logger posts each call site only once, so
            // this reports both the first timeout and the first one at the minimum page
            // size, which shows that shrinking pages did not help.
            if timeout.isAtMinimumPageSize {
                logger.postError(timeout)
            } else {
                logger.postError(timeout)
            }
            throw timeout
        }
    }
}
