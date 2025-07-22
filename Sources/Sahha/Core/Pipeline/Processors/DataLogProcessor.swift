import Foundation

final actor DataLogProcessor: BatchProcessor {
    private let storage: any BatchStorage<DataLog>
    private let uploader: any BatchUploader
    private let logger: Logger
    private let batchSize: Int
    private let maxBufferSize: Int

    private var buffer: [DataLog] = []
    private var perKeyCounts: [String: Int] = [:]
    private var perKeyWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    init(
        storage: any BatchStorage<DataLog>,
        uploader: any BatchUploader,
        logger: Logger,
        batchSize: Int = 100,
        maxBufferSize: Int = 10_000
    ) {
        self.storage = storage
        self.uploader = uploader
        self.logger = logger
        self.batchSize = batchSize
        self.maxBufferSize = maxBufferSize
    }
    
    func enqueue(_ item: DataLog, for key: String) async throws {
        try await enqueue( [item], for: key)
    }

    /// Enqueue logs for a specific sensor.
    func enqueue(_ items: [DataLog], for key: String) async throws {
        // Wait for buffer space if needed
        while buffer.count >= maxBufferSize {
            await waitUntilBufferBelowCap()
        }
        buffer.append(contentsOf: items)
        perKeyCounts[key, default: 0] += items.count
        try await processBuffer(for: key)
    }
    
    func dispose() async {
        buffer.removeAll()
        perKeyCounts.removeAll()
        perKeyWaiters.removeAll()
    }

    /// Wait for all logs for a specific sensor to be saved to disk.
    func waitTilProcessed(for key: String) async {
        if perKeyCounts[key, default: 0] == 0 { return }
        await withCheckedContinuation { cont in
            perKeyWaiters[key, default: []].append(cont)
        }
    }

    private func processBuffer(for key: String) async throws {
        while buffer.count >= batchSize {
            let batch = Array(buffer.prefix(batchSize))
            buffer.removeFirst(batchSize)

            do {
                let url = try await storage.save(batch: batch)
                perKeyCounts[key, default: 0] -= batch.count
                await uploader.upload(url: url)
                // Signal sensor if all logs are saved
                if perKeyCounts[key, default: 0] == 0 {
                    perKeyWaiters[key]?.forEach { $0.resume() }
                    perKeyWaiters[key] = []
                }
            } catch {
                buffer.insert(contentsOf: batch, at: 0)
                logger.error("Failed to save batch to disk: \(error). Returned batch to buffer.")
                break
            }
        }
    }

    // Optionally, implement buffer backpressure for extreme load
    private var bufferWaiters: [CheckedContinuation<Void, Never>] = []

    private func waitUntilBufferBelowCap() async {
        await withCheckedContinuation { cont in
            bufferWaiters.append(cont)
        }
    }

    // Call this method after you remove items from buffer (e.g., after save)
    private func signalBufferSpaceIfNeeded() {
        if buffer.count < maxBufferSize, let waiter = bufferWaiters.first {
            bufferWaiters.removeFirst()
            waiter.resume()
        }
    }
}
