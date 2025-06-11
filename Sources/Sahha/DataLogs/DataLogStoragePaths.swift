import Foundation

struct DataLogStoragePaths {
    let baseDirectory: URL

    var dataLogs: URL {
        baseDirectory.appendingPathComponent("data-logs", isDirectory: true)
    }

    var batches: URL {
        dataLogs.appendingPathComponent("batches", isDirectory: true)
    }

    var rawLogs: URL {
        dataLogs.appendingPathComponent("raw", isDirectory: true)
    }

    var aggregates: URL {
        dataLogs.appendingPathComponent("agg", isDirectory: true)
    }

    static func `default`() -> DataLogStoragePaths {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("sahha", isDirectory: true)
        
        return DataLogStoragePaths(baseDirectory: appSupport)
    }
}
