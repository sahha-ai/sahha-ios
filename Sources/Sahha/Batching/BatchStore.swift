import Foundation

final actor BatchStore<T: Codable & Sendable> {
    private let baseDirectory: URL
    private let storage: FileSystemStorage
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseDirectory: URL, storage: FileSystemStorage = FileSystemStorage()) throws {
        self.baseDirectory = baseDirectory
        self.storage = storage
    }

    func save(_ batch: [T]) throws {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let suffix = UUID().uuidString.prefix(6)
        let filename = "\(timestamp)_\(suffix).json"
        let url = baseDirectory.appendingPathComponent(filename)
        try storage.ensureDirectoryExists(at: url.deletingLastPathComponent())
        let data = try encoder.encode(batch)
        try storage.save(data, to: url)
    }

    func loadAll() throws -> [[T]] {
        let files = try storage.listFiles(in: baseDirectory)
        var batches: [[T]] = []

        for file in files where file.pathExtension == "json" {
            let data = try storage.load(from: file)
            let batch = try decoder.decode([T].self, from: data)
            batches.append(batch)
        }

        return batches
    }

    func deleteAll() throws {
        guard storage.directoryExists(at: baseDirectory) else { return }
        try storage.delete(at: baseDirectory)
    }

    func delete(file url: URL) throws {
        try storage.delete(at: url)
    }

    func listBatchFiles() throws -> [URL] {
        try storage.listFiles(in: baseDirectory).filter { $0.pathExtension == "json" }
    }
}
