import Foundation

final actor BatchUploader<T: Sendable & Encodable> {
    private let semaphore: AsyncSemaphore
    private let retryPolicy: BatchRetryPolicy
    private let endpointBuilder: ([T]) -> ApiEndpoint
    private let maxPendingBatches: Int
    
    private var queue = [() async -> Void]()
    
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
        guard queue.count < maxPendingBatches else { return false }

        queue.append {
            await self.upload(batch)
        }
        processQueue()
        return true
    }
    
    private func processQueue() {
        Task {
            guard let job = queue.first else { return }
            await semaphore.wait()
            queue.removeFirst()
            defer { Task { await semaphore.signal() } }
            await job()
            processQueue()
        }
    }
    
    private func upload(_ batch: [T], retryCount: Int = 0) async {
        let endpoint = endpointBuilder(batch)
        let result = await ApiClient.shared.send(endpoint)
        
        switch result {
        case .success:
            return
        case .failure(let error):
            if let delay = retryPolicy.delay(forRetry: retryCount) {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                await upload(batch, retryCount: retryCount + 1)
            }
        }
    }
}
