import Foundation

final actor BatchUploader<T: Sendable & Encodable> {
    private let semaphore: AsyncSemaphore
    private let retryPolicy: BatchRetryPolicy
    private let endpointBuilder: ([T]) -> ApiEndpoint
    private let maxPendingBatches: Int
    
    private var queue: [() async -> Void] = []
    private var activeTasks: Set<Task<Void, Never>> = []
    private var isCancelled = false
    
    init(
        maxConcurrentUploads: Int = 5,
        maxPendingBatches: Int = 100,
        retryPolicy: BatchRetryPolicy,
        endpointBuilder: @escaping ([T]) -> ApiEndpoint
    ) {
        self.semaphore = AsyncSemaphore(value: maxConcurrentUploads)
        self.maxPendingBatches = maxPendingBatches
        self.retryPolicy = retryPolicy
        self.endpointBuilder = endpointBuilder
    }
    
    func enqueue(_ batch: [T]) async -> Bool {
        guard !isCancelled && queue.count < maxPendingBatches else { return false }
        
        queue.append {
            await self.mockUpload(batch)
        }
        processQueue()
        return true
    }
    
    func cancelAll() async {
        isCancelled = true
        queue.removeAll()
        
        for task in activeTasks {
            task.cancel()
        }
        
        await withTaskGroup(of: Void.self) { group in
            for task in activeTasks {
                group.addTask {
                    await task.value
                }
            }
        }
        
        activeTasks.removeAll()
        isCancelled = false
        SahhaLogger.info("All upload tasks cancelled and cleared")
    }
    
    private func processQueue() {
        let task = Task {
            guard !isCancelled else { return }
            
            await semaphore.wait()
            defer { Task { await semaphore.signal() } }
            
            guard !isCancelled && !queue.isEmpty else { return }
            
            let job = queue.removeFirst()
            await job()
            
            if !isCancelled {
                processQueue()
            }
        }
        
        activeTasks.insert(task)
        
        Task {
            await task.value
            await self.removeCompletedTask(task)
        }
    }
    
    private func removeCompletedTask(_ task: Task<Void, Never>) async {
        activeTasks.remove(task)
    }
    
    private func upload(_ batch: [T], retryCount: Int = 0) async {
        guard !Task.isCancelled else {
            SahhaLogger.info("Upload task was cancelled before starting")
            return
        }
        
        let endpoint = endpointBuilder(batch)
        let result = await ApiClient.shared.send(endpoint)
        
        switch result {
        case .success:
            return
        case .failure(let error):
            guard !Task.isCancelled else {
                SahhaLogger.info("Upload task was cancelled after failure")
                return
            }
            
            print("error uploading batch: \(error.localizedDescription)")
            if let delay = retryPolicy.delay(forRetry: retryCount) {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await upload(batch, retryCount: retryCount + 1)
            }
        }
    }
    
    private func mockUpload(_ batch: [T], retryCount: Int = 0) async {
        SahhaLogger.info("Uploading batch with \(batch.count) items (retry #\(retryCount))")
        try? await Task.sleep(nanoseconds: 200_000_000)
        SahhaLogger.info("Successfully uploaded test batch")
        return
    }
}
