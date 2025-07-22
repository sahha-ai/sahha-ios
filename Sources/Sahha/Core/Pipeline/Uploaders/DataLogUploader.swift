import Foundation

final actor DataLogUploader: BatchUploader {
    private let api: APIClient
    private let requestFactory: DataLogRequestFactory
    private let semaphore: AsyncSemaphore
    private let storage: any BatchStorage
    private let logger: Logger

    private var activeUploadTasks: Set<Task<Void, Never>> = []

    init(
        api: APIClient,
        requestFactory: DataLogRequestFactory,
        maxConcurrentUploads: Int = 25,
        storage: any BatchStorage,
        logger: Logger
    ) {
        self.api = api
        self.requestFactory = requestFactory
        self.semaphore = AsyncSemaphore(value: maxConcurrentUploads)
        self.storage = storage
        self.logger = logger
    }

    func upload(url: URL) async {
        let uploadTask = Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            await self.uploadWithRetry(url: url)
        }
        await addUploadTask(uploadTask)
    }

    func dispose() async {
        for task in activeUploadTasks {
            task.cancel()
        }
        activeUploadTasks.removeAll()
    }

    private func addUploadTask(_ task: Task<Void, Never>) async {
        self.activeUploadTasks.insert(task)
        // Remove completed tasks automatically
        Task {
            await task.value
            await self.removeUploadTask(task)
        }
    }

    private func removeUploadTask(_ task: Task<Void, Never>) async {
        self.activeUploadTasks.remove(task)
    }

    private func uploadWithRetry(url: URL, retry: Int = 0) async {
        guard !Task.isCancelled else { return }
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }

        do {
            let data = try Data(contentsOf: url)
            let batch = try JSONDecoder().decode([DataLog].self, from: data)
            let dataLogRequests = await batch.asyncCompactMap(requestFactory.makeRequest)
            let request = APIRequest(endpoint: APIEndpoints.dataLog, method: .POST, body: dataLogRequests)
            // Uncomment for real API:
            // try await api.send(request)
            try await Task.sleep(nanoseconds: UInt64(50_000_000))
            logger.info("Upload successful. Batch file: \(url.lastPathComponent)")
            try await storage.deleteBatchFile(at: url)
        } catch {
            logger.warning("Upload failed for batch file: \(url.lastPathComponent), retry: \(retry). Error: \(error)")
            let backoff = pow(2.0, Double(min(retry, 5)))
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            await uploadWithRetry(url: url, retry: retry + 1)
        }
    }
}
