import Foundation

final actor FileManagerDataLogBatchStorage: DataLogBatchStoring {
    private let storage: FileManagerStoring
    private let fileExtension = "json"
    private let maxFileCount: Int

    private var nextId: UInt64
    private var fileWaiters: [CheckedContinuation<Void, Never>] = []
    private var fileCount: Int
    private var disposed = false

    init(storage: FileManagerStoring, maxFileCount: Int = 1000) async throws {
        self.storage = storage
        self.maxFileCount = maxFileCount
        self.nextId = UInt64(Date().timeIntervalSince1970 * 1000)
        self.fileCount = try await storage.listFiles(withExtension: fileExtension).count
    }

    func save(batch: [DataLog]) async throws -> URL {
        guard !disposed else { throw CancellationError() }
        // Suspend if we'd exceed the file limit
        while fileCount >= maxFileCount {
            await withCheckedContinuation { cont in
                fileWaiters.append(cont)
            }
        }
        guard !disposed else { throw CancellationError() }
        let filename = String(format: "%llu", nextId)
        nextId += 1
        let url = try await storage.write(batch, filename: filename, fileExtension: fileExtension)
        fileCount += 1
        return url
    }

    func load(url: URL) async throws -> [DataLog] {
        guard !disposed else { throw CancellationError() }
        return try await storage.read([DataLog].self, from: url)
    }

    func delete(url: URL) async throws {
        guard !disposed else { throw CancellationError() }
        try await storage.delete(at: url)
        fileCount = max(fileCount - 1, 0)
        wakeFileWaiters()
    }

    func listAllBatches() async throws -> [URL] {
        try await storage.listFiles(withExtension: fileExtension).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func wakeFileWaiters() {
        while fileWaiters.notEmpty && fileCount < maxFileCount {
            fileWaiters.removeFirst().resume()
        }
    }

    func dispose() async {
        disposed = true
        // Cancel all file waiters (unblocks any save calls)
        for waiter in fileWaiters {
            waiter.resume()
        }
        fileWaiters.removeAll()

        // Delete all batch files
        let batches = try? await listAllBatches()
        for url in batches ?? [] {
            try? await storage.delete(at: url)
        }
        fileCount = 0
    }
}
