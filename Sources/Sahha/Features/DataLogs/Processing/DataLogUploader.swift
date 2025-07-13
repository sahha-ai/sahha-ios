import Foundation

protocol DataLogUploader: Actor {
    func scheduleUpload(for url: URL) async
    func resumePendingUploads() async
}

final actor DataLogUploaderImpl: DataLogUploader {
    private let service: DataLogService
    private let storage: DataLogBatchStorage
    private let deviceId: String
    private let semaphore: AsyncSemaphore

    init(service: DataLogService, deviceId: String, storage: DataLogBatchStorage, maxConcurrentUploads: Int = 5) {
        self.service = service
        self.deviceId = deviceId
        self.storage = storage
        self.semaphore = AsyncSemaphore(value: max(maxConcurrentUploads, 1))
    }

    func scheduleUpload(for url: URL) async {
        Task.detached(priority: .background) { [weak self] in
            await self?.uploadLoop(url: url, retry: 0)
        }
    }

    func resumePendingUploads() async {
        for url in await storage.pendingBatchURLs() {
            await scheduleUpload(for: url)
        }
    }

    private func uploadLoop(url: URL, retry: Int) async {
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }

        do {
            let data = try Data(contentsOf: url)
            let logs = try JSONDecoder().decode([DataLog].self, from: data)
            let requests = logs.map { $0.toRequest(deviceId: deviceId) }
            try await service.postDataLogs(requests)
            await storage.deleteBatch(at: url)
        } catch {
            let backoff = pow(2.0, Double(min(retry, 5)))
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            await uploadLoop(url: url, retry: retry + 1)
        }
    }
}
