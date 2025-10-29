import Foundation

actor DataLogPipeline: DataLogPipelineProtocol, Disposable {
    private let maxBatchBytes: Int
    private let maxBufferSize: Int
    private let flushInterval: TimeInterval
    private let fileManager: DataLogFileManagerProtocol
    private let requestMapper: DataLogRequestMapperProtocol
    private let uploader: DataLogUploaderProtocol
    private let priorityAssigner: UploadPriorityAssignerProtocol
    private let streamingProcessor: StreamingBatchProcessor

    private var disposed = false
    private var buffer: [DataLog] = []
    private var bufferWaiters: [CheckedContinuation<Void, Never>] = []
    private var flushTask: Task<Void, Never>? = nil

    init(
        fileManager: DataLogFileManagerProtocol,
        requestMapper: DataLogRequestMapperProtocol,
        uploader: DataLogUploaderProtocol,
        priorityAssigner: UploadPriorityAssignerProtocol,
        maxBatchKB: Int = 150,
        maxBufferSize: Int = 50_000,
        flushInterval: TimeInterval = .seconds(5)
    ) {
        self.fileManager = fileManager
        self.requestMapper = requestMapper
        self.uploader = uploader
        self.priorityAssigner = priorityAssigner
        self.maxBatchBytes = maxBatchKB * 1024  // Store as bytes internally
        self.maxBufferSize = maxBufferSize
        self.flushInterval = flushInterval
        self.streamingProcessor = StreamingBatchProcessor(
            requestMapper: requestMapper,
            priorityAssigner: priorityAssigner,
            maxChunkKB: maxBatchKB,
            chunkSize: 100
        )
    }

    func ingest(_ logs: [DataLog]) async {
        guard !disposed else { return }

        await uploader.enqueueLogs(logs)
    }

    func ingest(_ log: DataLog) async {
        await ingest([log])
    }

    func dispose() async {
        disposed = true
        cancelFlushTimer()
        buffer.removeAll()
        bufferWaiters.forEach { $0.resume() }
        bufferWaiters.removeAll()
    }

    private func startFlushTimer() {
        flushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(flushInterval * 1_000_000_000))
            await self.timerFlush()
        }
    }

    private func cancelFlushTimer() {
        flushTask?.cancel()
        flushTask = nil
    }

    private func timerFlush() async {
        guard !buffer.isEmpty else {
            cancelFlushTimer()
            return
        }
        await flushBufferBySize()
        cancelFlushTimer()
    }

    func flushOnAppBackgroundOrExit() async {
        cancelFlushTimer()
        if !buffer.isEmpty {
            await flushBufferBySize()
        }
    }

    private func waitForBufferSpace(for count: Int) async {
        while buffer.count + count > maxBufferSize {
            await withCheckedContinuation { continuation in
                bufferWaiters.append(continuation)
            }
        }
    }

    private func tryResumeBufferWaiters() {
        while let continuation = bufferWaiters.first,
              buffer.count < maxBufferSize {
            bufferWaiters.removeFirst()
            continuation.resume()
        }
    }

    private func flushBufferBySize() async {
        // Use streaming processor for memory-efficient batch processing
        // This keeps memory usage constant regardless of buffer size
        guard !buffer.isEmpty else { return }
        
        // Take snapshot of buffer and clear it
        let logsToProcess = buffer
        buffer.removeAll()
        tryResumeBufferWaiters()
        
        print("[Sahha Streaming] Processing \(logsToProcess.count) logs as stream...")
        
        // Stream chunks and enqueue them for upload
        let chunkStream = await streamingProcessor.streamChunks(from: logsToProcess)
        var chunkCount = 0
        
        for await chunk in chunkStream {
            chunkCount += 1
            print("[Sahha Streaming] Processing chunk \(chunkCount): \(chunk.requests.count) logs, \(chunk.sizeInBytes) bytes, priority: \(chunk.priority)")
            await uploader.enqueue(chunk)
        }
        
        print("[Sahha Streaming] Completed processing \(chunkCount) chunks")
    }
}
