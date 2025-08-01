import Foundation

actor DataLogUploader: DataLogUploaderProtocol, Disposable {
    private let maxLogsPerUpload: Int
    private let maxBackoff: TimeInterval
    private let initialBackoff: TimeInterval
    private let fileManager: DataLogFileManagerProtocol
    private let dataLogService: DataLogServiceProtocol
    private let requestMapper: DataLogRequestMapperProtocol
    private let uploadSemaphore: AsyncSemaphore
    private let logger: ErrorLoggerProtocol

    private var uploadTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        dataLogService: DataLogServiceProtocol,
        requestMapper: DataLogRequestMapperProtocol,
        maxConcurrentUploads: Int = 5,
        maxLogsPerUpload: Int = 100,
        maxBackoff: TimeInterval = .seconds(30),
        initialBackoff: TimeInterval = .seconds(1),
        logger: ErrorLoggerProtocol
    ) {
        self.fileManager = fileManager
        self.dataLogService = dataLogService
        self.requestMapper = requestMapper
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
                        for chunk in logs.chunked(into: maxLogsPerUpload) {
                            let batch = self.requestMapper.map(chunk)
                            if Task.isCancelled { return }
                            await self.uploadBatch(batch, batchFile: fileURL)
                        }
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
            return try await dataLogService.postDataLogs(batch)
        } catch {
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
