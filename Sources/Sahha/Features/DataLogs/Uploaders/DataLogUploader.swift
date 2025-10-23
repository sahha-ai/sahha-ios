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
    private let priorityAssigner: UploadPriorityAssignerProtocol  
    private var priorityQueue: [UploadPriority: [DataLogRequest]] = [:]  

    private var uploadTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        dataLogService: DataLogServiceProtocol,
        requestMapper: DataLogRequestMapperProtocol,  
        maxConcurrentUploads: Int = 5,
        maxLogsPerUpload: Int = 100,
        maxBackoff: TimeInterval = .seconds(30),
        initialBackoff: TimeInterval = .seconds(1),
        logger: ErrorLoggerProtocol,
        priorityAssigner: UploadPriorityAssignerProtocol
    ) {
        self.fileManager = fileManager
        self.dataLogService = dataLogService
        self.requestMapper = requestMapper
        self.maxLogsPerUpload = maxLogsPerUpload
        self.initialBackoff = initialBackoff
        self.maxBackoff = maxBackoff
        self.logger = logger
        self.uploadSemaphore = AsyncSemaphore(value: max(maxConcurrentUploads, 1))
        self.priorityAssigner = priorityAssigner
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

    func ingestPrioritizedLogs(_ prioritizedLogs: [(DataLog, UploadPriority)]) async {
        for (log, priority) in prioritizedLogs {
            let request = try? await requestMapper.map(log)  
            if let request {
                priorityQueue[priority, default: []].append(request)
            }
        }
    }
    
    private func processPriorityQueue() async -> [UploadPriority: [DataLogRequest]] {
        let batches = priorityQueue 
        priorityQueue.removeAll()  
        return batches
    }

    private func uploadPriorityBatches(_ batches: [UploadPriority: [DataLogRequest]]) async {
        for (priority, logs) in batches.sorted(by: { $0.key > $1.key }) {
            print("[Sahha Priority] Uploading \(logs.count) logs with priority: \(priority)")
            await uploadBatch(logs, priority: priority)
        }
    }

    private func uploadBatch(_ batch: [DataLogRequest], priority: UploadPriority? = nil, batchFile: URL? = nil, attempt: Int = 0) async {
        if Task.isCancelled { return }
        do {
            return try await dataLogService.postDataLogs(batch)
        } catch {
            logger.postError(error)
            let waitTime = min(maxBackoff, initialBackoff * pow(2, Double(attempt)))
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            await uploadBatch(batch, priority: priority, batchFile: batchFile, attempt: attempt + 1)
        }
    }

    private func runUploadLoop() async {
        while true {
            if Task.isCancelled { break }
            let batchFiles = await fileManager.getAllBatchFiles()
            guard !batchFiles.isEmpty else { break }
            
            let priorityBatches = await processPriorityQueue()
            if !priorityBatches.isEmpty {
                await uploadPriorityBatches(priorityBatches)
            }
            
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




    func dispose() async {
        uploadTask?.cancel()
        uploadTask = nil
    }
}
