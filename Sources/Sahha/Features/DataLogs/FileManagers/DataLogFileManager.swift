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
        self.nextId = Self.seedNextId(in: batchDir)
    }

    func persistBatch(_ logs: [DataLogRequest]) async {
        guard !logs.isEmpty else { return }
        await waitForFileSpaceIfNeeded()
        let fileURL = batchDir.appendingPathComponent("\(nextId).bin")
        do {
            let data = try encodeBatch(logs)
            try data.write(to: fileURL, options: .atomic)
            nextId &+= 1
        } catch {
            logger.postError(error)
        }
    }

    func getAllBatchFiles() async -> [URL] {
        Self.batchFilesSortedNumerically(in: batchDir)
    }

    func readBatchFile(_ url: URL) async -> [DataLogRequest]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if let logs = try? decodeBatch(data) {
            return logs
        }
        await deleteBatchFile(url)
        return nil
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
        (try? FileManager.default.contentsOfDirectory(
            at: batchDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?
        .filter { $0.pathExtension == "bin" && UInt64($0.deletingPathExtension().lastPathComponent) != nil }
            ?? []
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

    private func encodeBatch(_ logs: [DataLogRequest]) throws -> Data {
        var batchData = Data()
        for log in logs {
            let logData = try encoder.encode(log)
            var length = UInt32(logData.count)
            batchData.append(Data(bytes: &length, count: 4))
            batchData.append(logData)
        }
        return batchData
    }

    private func decodeBatch(_ data: Data) throws -> [DataLogRequest] {
        var logs: [DataLogRequest] = []
        var cursor = data.startIndex
        while cursor < data.endIndex {
            guard data.endIndex - cursor >= UInt32.byteWidth else { break }
            let length = Int(data.toUInt32(at: cursor))
            cursor += UInt32.byteWidth
            guard data.endIndex - cursor >= length else { break }
            let logData = data[cursor..<cursor + length]
            cursor += length
            let log = try decoder.decode(DataLogRequest.self, from: Data(logData))
            logs.append(log)
        }
        return logs
    }

    private static func batchFilesSortedNumerically(in directory: URL) -> [URL] {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []

        return
            files
            .filter {
                $0.pathExtension == "bin" && UInt64($0.deletingPathExtension().lastPathComponent) != nil
            }
            .sorted {
                let a = UInt64($0.deletingPathExtension().lastPathComponent) ?? 0
                let b = UInt64($1.deletingPathExtension().lastPathComponent) ?? 0
                return a < b
            }
    }

    private static func seedNextId(in dir: URL) -> UInt64 {
        if let maxFile = batchFilesSortedNumerically(in: dir).last,
            let n = UInt64(maxFile.deletingPathExtension().lastPathComponent)
        {
            return n &+ 1
        }
        return UInt64((Date().timeIntervalSince1970 * 1000).rounded())
    }
}
