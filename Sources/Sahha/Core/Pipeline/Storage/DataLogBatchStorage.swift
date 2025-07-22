import Foundation

final actor DataLogBatchStorage: BatchStorage {
    private let directory: URL
    private let maxBatchCount: Int
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let logger: Logger

    private var nextId: UInt64
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(
        directory: URL,
        maxBatchCount: Int = 200,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        logger: Logger
    ) {
        self.directory = directory
        self.maxBatchCount = maxBatchCount
        self.fileManager = fileManager
        self.encoder = encoder
        self.nextId = UInt64(Date().timeIntervalSince1970 * 1_000)
        self.logger = logger
    }

    func save(batch: [DataLog]) async throws -> URL {
        while try await loadAllBatchURLs().count >= maxBatchCount {
            await withCheckedContinuation { waiters.append($0) }
        }
        let data = try encoder.encode(batch)
        let tmp = directory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tmp, options: .atomic)
        let finalName = String(format: "%llu.json", nextId)
        nextId += 1
        let finalURL = directory.appendingPathComponent(finalName)
        try fileManager.moveItem(at: tmp, to: finalURL)
       
        return finalURL
    }

    func loadAllBatchURLs() async throws -> [URL] {
        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        return
            files
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func deleteBatchFile(at url: URL) async throws {
        do {
            try fileManager.removeItem(at: url)
            resumeOneWaitingWriter()
        } catch {
            logger.error("Failed to delete batch file: \(error)")
        }
    }

    func dispose() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: [])
            for file in files {
                do {
                    try fileManager.removeItem(at: file)
                } catch {
                    logger.error("Failed to delete batch file: \(error)")
                }
            }
        } catch {
            logger.error("Failed to empty batch directory: \(error)")
        }
    }
    
    private func resumeOneWaitingWriter() {
        if let cont = waiters.first {
            waiters.removeFirst()
            cont.resume()
        }
    }
}
