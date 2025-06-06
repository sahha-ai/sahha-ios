import Foundation

final actor BatchStore<T: Codable & Sendable> {
    private let storage: FileSystemStorage
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL, storage: FileSystemStorage = FileSystemStorage()) throws {
        self.storage = storage
        self.directory = directory
        try storage.ensureDirectoryExists(at: directory)
    }

    func save(_ batch: [T]) throws {
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
        let suffix = UUID().uuidString.prefix(6)
        let filename = "\(timestamp)_\(suffix).json"
        let url = directory.appendingPathComponent(filename)
        let data = try encoder.encode(batch)
        try storage.save(data, to: url)
    }

    func loadAll() throws -> [[T]] {
        let files = try storage.listFiles(in: directory)
        var batches: [[T]] = []

        for file in files where file.pathExtension == "json" {
            let data = try storage.load(from: file)
            let batch = try decoder.decode([T].self, from: data)
            batches.append(batch)
        }

        return batches
    }

    func deleteAll() throws {
        let files = try storage.listFiles(in: directory)
        for file in files where file.pathExtension == "json" {
            try storage.delete(at: file)
        }
    }

    func delete(file url: URL) throws {
        try storage.delete(at: url)
    }

    func listBatchFiles() throws -> [URL] {
        try storage.listFiles(in: directory).filter { $0.pathExtension == "json" }
    }
}
