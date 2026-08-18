import Foundation
@testable import Sahha

/// Error-logger double that records every posted error for assertion.
final class RecordingErrorLogger: ErrorLoggerProtocol, @unchecked Sendable {
    struct Posted {
        let error: Error
        let file: String
        let function: String
        let line: UInt
    }

    private let lock = NSLock()
    private var posted: [Posted] = []

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return posted.count
    }

    /// Returns everything posted so far and clears the record.
    @discardableResult
    func drain() -> [Posted] {
        lock.lock(); defer { lock.unlock() }
        let drained = posted
        posted = []
        return drained
    }

    func postError(_ error: Error, file: StaticString, function: StaticString, line: UInt) {
        lock.lock(); defer { lock.unlock() }
        posted.append(Posted(error: error, file: file.description, function: function.description, line: line))
    }
}
