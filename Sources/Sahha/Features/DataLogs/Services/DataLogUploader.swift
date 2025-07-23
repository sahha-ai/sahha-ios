import Foundation

final actor DataLogUploader: DataLogUploading {
    private let apiClient: APIClientProviding
    private let batchStorage: DataLogBatchStoring
    private let maxConcurrentUploads: Int
    private let maxBackoff: TimeInterval
    private let initialBackoff: TimeInterval
    private let semaphore: AsyncSemaphore
    private let requestFactory: DataLogRequestMapping
    private let logger: ErrorLogger

    private var disposed = false
    private var uploadTasks: [URL: Task<Void, Never>] = [:]

    init(
        apiClient: APIClientProviding,
        batchStorage: DataLogBatchStoring,
        maxConcurrentUploads: Int = 20,
        maxBackoff: TimeInterval = .seconds(30),
        initialBackoff: TimeInterval = .seconds(1),
        requestFactory: DataLogRequestMapping,
        logger: ErrorLogger
    ) {
        self.apiClient = apiClient
        self.batchStorage = batchStorage
        self.maxConcurrentUploads = maxConcurrentUploads
        self.semaphore = AsyncSemaphore(value: maxConcurrentUploads)
        self.maxBackoff = maxBackoff
        self.initialBackoff = initialBackoff
        self.requestFactory = requestFactory
        self.logger = logger
    }

    /// Enqueue a batch file for upload.
    func enqueue(_ batchURL: URL) {
        Task { await self.startUpload(for: batchURL) }
    }

    /// Upload all batches present in storage directory (called on startup)
    func uploadPendingBatches() {
        Task {
            let batchURLs = (try? await batchStorage.listAllBatches()) ?? []
            for url in batchURLs {
                await self.startUpload(for: url)
            }
        }
    }

    /// Actually schedule the upload if not already in progress.
    private func startUpload(for batchURL: URL) async {
        // Prevent duplicate uploads for the same file
        guard !disposed, uploadTasks[batchURL] == nil else { return }

        let uploadTask = Task {
            await semaphore.wait()
            defer {
                Task {
                    await semaphore.signal()
                    self.uploadTasks[batchURL] = nil
                }
            }

            var attempt = 0
            while true {
                guard !Task.isCancelled else { return }
                do {
                    let dataLogs = try await batchStorage.load(url: batchURL)
                    let dataLogRequests = try await requestFactory.map(dataLogs)
                    try await apiClient.send(.postDataLogs(dataLogRequests))
                    try await batchStorage.delete(url: batchURL)
                    break
                } catch is CancellationError {
                    break
                } catch {
                    attempt += 1
                    // Wait with exponential backoff (capped)
                    let waitTime = min(maxBackoff, initialBackoff * pow(2, Double(attempt)))
                    logger.sdkError("Upload failed for \(batchURL.lastPathComponent), retrying in \(waitTime)", error: error)
                    try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                }
            }
        }
        uploadTasks[batchURL] = uploadTask
    }

    func dispose() async {
        disposed = true
        for (_, task) in uploadTasks { task.cancel() }
        for (_, task) in uploadTasks { await task.value }
        uploadTasks.removeAll()
    }
}
