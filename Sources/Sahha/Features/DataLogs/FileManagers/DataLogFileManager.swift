import Foundation

actor DataLogFileManager: DataLogFileManagerProtocol, Disposable {
    private let maxBatchFileCount: Int
    private let encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()
    private let decoder = PropertyListDecoder()
    private let batchDir: URL
    private let logger: ErrorLoggerProtocol

    private var nextId: UInt64
    private var fileWaiters: [CheckedContinuation<Void, Never>] = []

    init(directory: URL, logger: ErrorLoggerProtocol, maxBatchFileCount: Int = 250) throws {
        self.batchDir = directory.appendingPathComponent("batches", isDirectory: true)
        try FileManager.default.createDirectory(at: batchDir, withIntermediateDirectories: true)
        self.maxBatchFileCount = maxBatchFileCount
        self.logger = logger
        self.nextId = UInt64(Date().timeIntervalSince1970)
    }

    func persistBatch(_ logs: [DataLog]) async {
        guard !logs.isEmpty else { return }
        await waitForFileSpaceIfNeeded()
        let fileURL = batchDir.appendingPathComponent("\(nextId).bin")
        nextId += 1
        do {
            let data = try encodeBatch(logs)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.postError(error)
        }
    }

    func getAllBatchFiles() async -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: batchDir, includingPropertiesForKeys: nil)) ?? []
        return
            files
            .filter { $0.pathExtension == "bin" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func readBatchFile(_ url: URL) async -> [DataLog]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let logs = try? decodeBatch(data)
        return logs
    }

    func deleteBatchFile(_ url: URL) async {
        do {
            try FileManager.default.removeItem(at: url)
            notifyFileWaitersIfNeeded()
        } catch {
            logger.postError(error)
        }
    }

    func dispose() async {
        for url in currentFiles {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                logger.postError(error)
            }
        }
        fileWaiters.forEach { $0.resume() }
        fileWaiters.removeAll()
    }

    private var currentFiles: [URL] {
        let contentsOfDirectory = try? FileManager.default.contentsOfDirectory(at: batchDir, includingPropertiesForKeys: nil)
        return contentsOfDirectory?.filter { $0.pathExtension == "bin" } ?? []
    }

    private var currentFileCount: Int {
        currentFiles.count
    }

    private func waitForFileSpaceIfNeeded() async {
        while currentFileCount >= maxBatchFileCount {
            await withCheckedContinuation { continuation in
                fileWaiters.append(continuation)
            }
        }
    }

    private func notifyFileWaitersIfNeeded() {
        while currentFileCount < maxBatchFileCount, !fileWaiters.isEmpty {
            let waiter = fileWaiters.removeFirst()
            waiter.resume()
        }
    }

    private func encodeBatch(_ logs: [DataLog]) throws -> Data {
        var batchData = Data()
        for log in logs {
            let logData = try encoder.encode(log)
            var length = UInt32(logData.count)
            batchData.append(Data(bytes: &length, count: 4))
            batchData.append(logData)
        }
        return batchData
    }

    private func decodeBatch(_ data: Data) throws -> [DataLog] {
        var logs: [DataLog] = []
        var cursor = data.startIndex
        while cursor < data.endIndex {
            guard data.endIndex - cursor >= UInt32.byteWidth else { break }
            let length = Int(data.toUInt32(at: cursor))
            cursor += UInt32.byteWidth
            guard data.endIndex - cursor >= length else { break }
            let logData = data[cursor..<cursor + length]
            cursor += length
            let log = try decoder.decode(DataLog.self, from: Data(logData))
            logs.append(log)
        }
        return logs
    }
}
