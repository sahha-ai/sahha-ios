import Foundation

final actor DataLogProcessor: DataLogProcessorProtocol {
    private let batchManager: BatchManager<DataLog>
    private let dataLogService: DataLogServiceProtocol
    private let semaphore: AsyncSemaphore

    private var processingTask: Task<Void, Never>?

    init(batchManager: BatchManager<DataLog>, dataLogService: DataLogServiceProtocol, maxConcurrentUploads: Int = 3) {
        self.batchManager = batchManager
        self.dataLogService = dataLogService
        self.semaphore = AsyncSemaphore(value: max(1, maxConcurrentUploads))
        Task.detached { [weak self] in
            await self?.processBatches()
        }
    }

    func process(_ inputs: [DataLog]) async throws {
        let maxRetries = 3
        var attempts = 0

        while attempts < maxRetries {
            if await isAcceptingData() {
                await batchManager.add(inputs)
                await processBatches()
                return
            }
            try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            attempts += 1
        }

        if await isAcceptingData() {
            await batchManager.add(inputs)
            await processBatches()
        } else {
            throw DataLogError.processorNotAcceptingData
        }
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

        print("Processing batches...")

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
                            print("Processed and deleted batch at \(url)")
                        } catch {
                            print("Failed to process batch at \(url): \(error)")
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

    private func uploadBatchWithRetry(_ batch: [DataLog]) async throws {
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
                print("Upload attempt \(attempts + 1) failed: \(error). Retrying after \(delay)s")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                attempts += 1
            }
        }

        throw DataLogError.maxUploadRetriesExceeded
    }
}
