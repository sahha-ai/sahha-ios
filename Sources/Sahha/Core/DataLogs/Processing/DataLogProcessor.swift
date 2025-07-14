protocol DataLogProcessor: Actor {
    func enqueue(_ logs: [DataLog]) async
}

final actor DataLogProcessorImpl: DataLogProcessor {
    private let maxBufferedLogs = 2000
    private let batchSize: Int
    private let logger: Logger
    private let storage: DataLogBatchStorage
    private let uploader: DataLogUploader
   
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var buffer: [DataLog] = []

    init(batchSize: Int = 100, logger: Logger, storage: DataLogBatchStorage, uploader: DataLogUploader) {
        self.batchSize = batchSize
        self.logger = logger
        self.storage = storage
        self.uploader = uploader

        Task { await uploader.resumePendingUploads() }
    }

    func enqueue(_ logs: [DataLog]) async {
        while buffer.count >= maxBufferedLogs {
            await waitUntilBufferBelowCap()
        }
        
        buffer.append(contentsOf: logs)
        
        while buffer.count >= batchSize {
            let slice = Array(buffer.prefix(batchSize))
            buffer.removeFirst(batchSize)

            do {
                let url = try await storage.saveBatch(slice)
                await uploader.scheduleUpload(for: url)
                resumeOneWaitingWriter()
            } catch {
                // Put back into buffer if disk write fails
                buffer.insert(contentsOf: slice, at: 0)
                logger.error("Failed to save batch to disk: \(error.localizedDescription)")
                break
            }
        }
    }
    
    private func waitUntilBufferBelowCap() async {
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }

    private func resumeOneWaitingWriter() {
        if let cont = waiters.first {
            waiters.removeFirst()
            cont.resume()
        }
    }
}
