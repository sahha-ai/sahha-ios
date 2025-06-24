import Foundation

protocol DataLogProcessorProtocol: Actor, DisposableAsync {
    func processData(_ data: [any DataLogType]) async throws
    func isAcceptingData() async -> Bool
}

actor DataLogProcessor: DataLogProcessorProtocol {
    private let batchManager: any BatchManagerProtocol<DataLogRequest>
    private let aggregationManager: DataLogAggregationManagerProtocol
    private let dataLogSerivce: DataLogServiceProtocol
    private let deviceInfoStore: DeviceInfoStoreProtocol
    private let semaphore: AsyncSemaphore

    private var isUploading: Bool = false
    private var uploadTasks: Set<Task<Void, Never>> = []

    init(
        batchManager: any BatchManagerProtocol<DataLogRequest>,
        aggregationManager: DataLogAggregationManagerProtocol,
        dataLogSerivce: DataLogServiceProtocol,
        deviceInfoStore: DeviceInfoStoreProtocol,
        maxConcurrentUploads: Int = 10
    ) async {
        self.batchManager = batchManager
        self.aggregationManager = aggregationManager
        self.dataLogSerivce = dataLogSerivce
        self.deviceInfoStore = deviceInfoStore
        self.semaphore = AsyncSemaphore(value: maxConcurrentUploads)
    }

    func processData(_ data: [any DataLogType]) async throws {
        print("[\(Date().isoDateTime)] Processing \(data.count) data logs")
        let deviceInfo = await deviceInfoStore.deviceInfo
        let requests = await data.concurrentCompactMap {
            $0.toRequest(deviceInfo: deviceInfo)
        }
        print("[\(Date().isoDateTime)] Converted \(data.count) data logs to \(requests.count) requests")
        try await batchManager.add(requests)
        print("[\(Date().isoDateTime)] Added \(requests.count) requests to batch manager")
        if !isUploading {
            print("[\(Date().isoDateTime)] Starting batch upload")
            Task.detached {
                await self.uploadBatches()
            }
        }
    }

    private func uploadBatches() async {
        guard !isUploading else {
            print("[\(Date().isoDateTime)] Upload already in progress, skipping")
            return
        }
        isUploading = true
        print("[\(Date().isoDateTime)] Started uploading batches")
        defer {
            isUploading = false
            print("[\(Date().isoDateTime)] Finished uploading batches")
        }
        while await batchManager.hasBatches {
            if let batch = await batchManager.getNextBatch() {
                print("[\(Date().isoDateTime)] Retrieved batch \(batch.id) with \(batch.batch.count) requests")
                await semaphore.wait()
                let task = Task.detached {
                    print("[\(Date().isoDateTime)] Uploading batch \(batch.id)")
                    await self.uploadBatch(batch.batch)
                    print("[\(Date().isoDateTime)] Upload succeeded for batch \(batch.id)")
                    do {
                        try await self.batchManager.removeBatch(id: batch.id)
                        print("[\(Date().isoDateTime)] Removed batch \(batch.id)")
                    } catch {
                        print("[\(Date().isoDateTime)] File already deleted for batch \(batch.id)")
                    }
                    await self.semaphore.signal()
                }
                uploadTasks.insert(task)
                Task {
                    await task.value
                    self.uploadTasks.remove(task)
                    print("[\(Date().isoDateTime)] Completed task for batch \(batch.id)")
                }
            }
        }
    }

    private func uploadBatch(_ batch: [DataLogRequest], attempt: Int = 0) async {
        let delays: [TimeInterval] = [1.0, 3.0, 5.0]  // 1s, 3s, 5s, then 5s indefinitely

        do {
            // Simulate network request - add real api request after testing
            try await Task.sleep(nanoseconds: UInt64(1_000_000_000))
            print("[\(Date().isoDateTime)] Simulated upload completed")
        } catch {
            let delayIndex = min(attempt, delays.count - 1)
            let delay = delays[delayIndex]
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await uploadBatch(batch, attempt: attempt + 1)
        }
    }

    func isAcceptingData() async -> Bool {
        let accepting = await batchManager.isAcceptingData
        print("[\(Date().isoDateTime)] Checked isAcceptingData: \(accepting)")
        return accepting
    }

    func dispose() async {
        for task in uploadTasks {
            task.cancel()
        }
        uploadTasks.removeAll()
        await batchManager.dispose()
    }

}
