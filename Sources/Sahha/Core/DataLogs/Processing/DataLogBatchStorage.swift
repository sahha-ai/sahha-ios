import Foundation

protocol DataLogBatchStorage: Actor, Disposable {
    func saveBatch(_ logs: [DataLog]) async throws -> URL
    func pendingBatchURLs() -> [URL]
    func deleteBatch(at url: URL)
}

final actor DataLogBatchStorageImpl: DataLogBatchStorage {
    private let directory: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let maxBatchCount: Int

    private var nextId: UInt64
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(directory: URL, maxBatchCount: Int = 250, fileManager: FileManager = .default, encoder: JSONEncoder = JSONEncoder()) {
        self.directory = directory
        self.maxBatchCount = maxBatchCount
        self.fileManager = fileManager
        self.encoder = encoder
        self.nextId = UInt64(Date().timeIntervalSince1970 * 1_000)
    }

    func saveBatch(_ logs: [DataLog]) async throws -> URL {
        while pendingBatchURLs().count >= maxBatchCount {
            await withCheckedContinuation { waiters.append($0) }
        }

        let data = try encoder.encode(logs)
        let tmp = directory.appendingPathComponent(UUID().uuidString)
        try data.write(to: tmp, options: .atomic)

        let finalName = String(format: "%llu.json", nextId)
        nextId += 1
        let finalURL = directory.appendingPathComponent(finalName)
        try fileManager.moveItem(at: tmp, to: finalURL)
        return finalURL
    }

    func pendingBatchURLs() -> [URL] {
        if let urls = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            return urls
        }
        return []
    }

    func deleteBatch(at url: URL) {
        try? fileManager.removeItem(at: url)
        resumeOneWaitingWriter()
    }
    
    func dispose() async {
        try? fileManager.removeItem(at: directory)
    }

    private func resumeOneWaitingWriter() {
        if let cont = waiters.first {
            waiters.removeFirst()
            cont.resume()
        }
    }
}
