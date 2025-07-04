import Foundation

protocol DataLogProcessorProtocol: Actor, DisposableAsync {
    func process(_ inputs: [DataLog]) async
    func isAcceptingData() async -> Bool
}

final actor DataLogProcessor: DataLogProcessorProtocol {
    private let logger: LoggerProtocol
    private let batchManager: BatchManager<DataLogRequest>
    private let dataLogService: DataLogServiceProtocol
    private let semaphore: AsyncSemaphore
    private let deviceInformation: DeviceInformation

    private var processingTask: Task<Void, Never>?

    init(
        logger: LoggerProtocol,
        batchManager: BatchManager<DataLogRequest>,
        dataLogService: DataLogServiceProtocol,
        deviceInformation: DeviceInformation,
        maxConcurrentUploads: Int = 10
    ) {
        self.logger = logger
        self.batchManager = batchManager
        self.dataLogService = dataLogService
        self.deviceInformation = deviceInformation
        self.semaphore = AsyncSemaphore(value: max(1, maxConcurrentUploads))
        Task.detached { [weak self] in
            await self?.processBatches()
        }
    }

    func process(_ inputs: [DataLog]) async {
        let requests = inputs.map { DataLogRequest.create(from: $0, deviceInformation: deviceInformation) }
        await batchManager.add(requests)
        await processBatches()
    }

    func isAcceptingData() async -> Bool {
        return await batchManager.isAcceptingData
    }

    func dispose() async throws {
        processingTask?.cancel()
        processingTask = nil
        await semaphore.waitForAll()
        try await batchManager.cleanup()
    }

    private func processBatches() async {
        guard processingTask == nil else { return }

        processingTask = Task {
            defer { self.processingTask = nil }

            await withTaskGroup(of: Void.self) { group in
                while !Task.isCancelled {
                    await semaphore.wait()

                    guard let (batch, url) = await batchManager.getNextBatch() else {
                        await semaphore.signal()
                        break
                    }

                    group.addTask { [weak self] in
                        do {
                            try await self?.uploadBatchWithRetry(batch)
                            try await self?.batchManager.deleteBatch(url: url)
                            self?.logger.info("Processed and deleted batch")
                        } catch {
                            self?.logger.error("Failed to process batch at \(url): \(error)", file: #file, function: #function)
                            await self?.batchManager.add(batch)
                        }
                        await self?.semaphore.signal()
                    }
                }

                await group.waitForAll()
            }
        }

        await processingTask?.value
    }

    private func uploadBatchWithRetry(_ batch: [DataLogRequest]) async throws {
        let retryDelays: [TimeInterval] = [1.0, 3.0, 5.0]
        let maxRetries = 100
        var attempts = 0

        while attempts < maxRetries {
            do {
                try await dataLogService.postDataLogs(batch)
                return
            } catch {
                try Task.checkCancellation()

                let delayIndex = min(attempts, retryDelays.count - 1)
                let delay = retryDelays[delayIndex]
                logger.info("Upload attempt \(attempts + 1) failed: \(error). Retrying after \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempts += 1
            }
        }

        throw DataLogError.maxUploadRetriesExceeded
    }
}
