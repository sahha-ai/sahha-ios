import Foundation

struct FileSystemStorage {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func ensureDirectoryExists(at url: URL) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw SahhaError.fileStorage(message: "Failed to create directory at \(url.path): \(error.localizedDescription)")
            }
        } else if !isDirectory.boolValue {
            throw SahhaError.fileStorage(message: "Path exists but is not a directory: \(url.path)")
        }
    }

    func save(_ data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw SahhaError.fileStorage(message: "Failed to write data to \(url.path): \(error.localizedDescription)")
        }
    }

    func load(from url: URL) throws -> Data {
        do {
            return try Data(contentsOf: url)
        } catch {
            throw SahhaError.fileStorage(message: "Failed to load data from \(url.path): \(error.localizedDescription)")
        }
    }

    func delete(at url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw SahhaError.fileStorage(message: "Failed to delete file at \(url.path): \(error.localizedDescription)")
        }
    }

    func listFiles(in directory: URL) throws -> [URL] {
        do {
            let fileNames = try fileManager.contentsOfDirectory(atPath: directory.path)
            return fileNames.map { directory.appendingPathComponent($0) }
        } catch {
            throw SahhaError.fileStorage(message: "Failed to list files in \(directory.path): \(error.localizedDescription)")
        }
    }

    func append(_ data: Data, to url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try save(data, to: url)
            return
        }

        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            throw SahhaError.fileStorage(message: "Failed to append data to \(url.path): \(error.localizedDescription)")
        }
    }
}
