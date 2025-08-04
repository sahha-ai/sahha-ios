import Foundation

actor DataLogUploader: DataLogUploaderProtocol, Disposable {
    private let maxLogsPerUpload: Int
    private let maxBackoff: TimeInterval
    private let initialBackoff: TimeInterval
    private let fileManager: DataLogFileManagerProtocol
    private let dataLogService: DataLogServiceProtocol
    private let uploadSemaphore: AsyncSemaphore
    private let logger: ErrorLoggerProtocol

    private var uploadTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        dataLogService: DataLogServiceProtocol,
        maxConcurrentUploads: Int = 5,
        maxLogsPerUpload: Int = 100,
        maxBackoff: TimeInterval = .seconds(30),
        initialBackoff: TimeInterval = .seconds(1),
        logger: ErrorLoggerProtocol
    ) {
        self.fileManager = fileManager
        self.dataLogService = dataLogService
        self.maxLogsPerUpload = maxLogsPerUpload
        self.initialBackoff = initialBackoff
        self.maxBackoff = maxBackoff
        self.logger = logger
        self.uploadSemaphore = AsyncSemaphore(value: max(maxConcurrentUploads, 1))
    }

    func uploadPendingBatches() {
        guard uploadTask == nil else { return }
        let task = Task { [weak self] in
            if let self {
                await self.runUploadLoop()
            }
        }
        uploadTask = task
    }

    private func runUploadLoop() async {
        while true {
            if Task.isCancelled { break }
            let batchFiles = await fileManager.getAllBatchFiles()
            guard !batchFiles.isEmpty else { break }
            await withTaskGroup(of: Void.self) { group in
                for fileURL in batchFiles {
                    group.addTask { [fileManager, maxLogsPerUpload] in
                        await self.uploadSemaphore.wait()
                        defer { Task { await self.uploadSemaphore.signal() } }
                        guard let logs = await fileManager.readBatchFile(fileURL) else { return }
                        if Task.isCancelled { return }
                        await self.uploadBatch(logs, batchFile: fileURL)
                        await fileManager.deleteBatchFile(fileURL)
                    }
                }
            }
        }
        uploadTask = nil
    }

    private func uploadBatch(_ batch: [DataLogRequest], batchFile: URL, attempt: Int = 0) async {
        if Task.isCancelled { return }
        do {
            print("Upload \(batch.count) logs...")

                   // Log batch JSON size
                   if let batchJson = try? JSONEncoder().encode(batch) {
                       print("Batch JSON size: \(batchJson.count) bytes (\(Double(batchJson.count) / 1024.0) KB)")
                   }

                   // Gather statistics for individual log sizes
                   var sizes: [Int] = []
                   for log in batch {
                       if let logJson = try? JSONEncoder().encode(log) {
                           sizes.append(logJson.count)
                       }
                   }
                   if !sizes.isEmpty {
                       let minSize = sizes.min()!
                       let maxSize = sizes.max()!
                       let avgSize = Double(sizes.reduce(0, +)) / Double(sizes.count)
                       let totalSize = sizes.reduce(0, +)
                       print("""
                           Log JSON size stats:
                           min: \(minSize) bytes (\(Double(minSize)/1024.0) KB),
                           max: \(maxSize) bytes (\(Double(maxSize)/1024.0) KB),
                           avg: \(String(format: "%.2f", avgSize)) bytes (\(String(format: "%.2f", avgSize/1024.0)) KB),
                           total: \(totalSize) bytes (\(Double(totalSize)/1024.0) KB)
                           """)
                   }
            
            return try await dataLogService.postDataLogs(batch)
        } catch {
            print("Failed to upload \(batch.count) logs. Retrying...", error)
            logger.postError(error)
            let waitTime = min(maxBackoff, initialBackoff * pow(2, Double(attempt)))
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            await uploadBatch(batch, batchFile: batchFile, attempt: attempt + 1)
        }
    }

    func dispose() async {
        uploadTask?.cancel()
        uploadTask = nil
    }
}
