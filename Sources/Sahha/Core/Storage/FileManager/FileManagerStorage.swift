import Foundation

final actor FileManagerStorage: FileManagerStoring {
    private let directory: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    
    private func url(for id: String, fileExtension: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension(fileExtension)
    }

    func write<T: Encodable>(_ object: T, filename: String, fileExtension: String = "json") throws -> URL {
        let fileURL = url(for: filename, fileExtension: fileExtension)
        let data = try JSONEncoder().encode(object)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func delete(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func listFiles(withExtension ext: String? = nil) throws -> [URL] {
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        if let ext = ext {
            return files.filter { $0.pathExtension == ext }
        } else {
            return files
        }
    }
}
