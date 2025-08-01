import HealthKit

actor HealthKitDataLogCoordinator: HealthKitDataLogCoordinatorProtocol, Disposable {
    private let observerService: HealthKitObserverServiceProtocol
    private let anchorQueryService: HealthKitAnchorQueryServiceProtocol
    private let anchorStore: HealthKitAnchorStoreProtocol
    private let normaliser: HKSampleToDataLogNormaliserProtocol
    private let dataLogPipeline: DataLogPipelineProtocol
    private let logger: ErrorLoggerProtocol
    private let queryLimit: Int

    private var observerTasks: [Task<Void, Never>] = []
    private let queryTasks = SingleThrowingTaskActorMap<String, Void>()

    init(
        observerService: HealthKitObserverServiceProtocol,
        anchorQueryService: HealthKitAnchorQueryServiceProtocol,
        anchorStore: HealthKitAnchorStoreProtocol,
        normaliser: HKSampleToDataLogNormaliserProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
        logger: ErrorLoggerProtocol,
        queryLimit: Int = 500
    ) {
        self.observerService = observerService
        self.anchorQueryService = anchorQueryService
        self.anchorStore = anchorStore
        self.normaliser = normaliser
        self.dataLogPipeline = dataLogPipeline
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

    func querySensors(_ sensors: Set<SahhaSensor>) async {
        for sensor in sensors {
            if let sampleType = sensor.hkSampleType {
                await launchTrackedQuery(for: sensor, sampleType: sampleType)
            }
        }
    }

    private func launchTrackedQuery(for sensor: SahhaSensor, sampleType: HKSampleType) async {
        let task = Task { [weak self] in
            if let self {
                await self.runSensorQuery(for: sensor, sampleType: sampleType)
            }
        }
        observerTasks.append(task)
    }

    private func runSensorQuery(for sensor: SahhaSensor, sampleType: HKSampleType) async {
        let key = sensor.rawValue

        do {
            try await queryTasks.run(for: key) { [weak self] in
                guard let self else { return }

                var anchor = try await anchorStore.loadAnchor(for: sensor)

                while !Task.isCancelled {
                    let (samples, newAnchor) = try await anchorQueryService.runAnchorQuery(
                        for: sampleType,
                        anchor: anchor,
                        limit: queryLimit
                    )
                    guard !samples.isEmpty else { break }
                    let dataLogs = samples.flatMap { self.normaliser.normalise($0) }
                    guard !Task.isCancelled else { break }
                    await self.dataLogPipeline.ingest(dataLogs)
                    if let newAnchor {
                        anchor = newAnchor
                         try await anchorStore.saveAnchor(newAnchor, for: sensor)
                    }
                }
            }
        } catch {
            logger.postError(error)
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
