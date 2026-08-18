import Foundation
@testable import Sahha

// NOTE: no `import Testing` in this file. The uploader protocols reference the SDK's
// `Tag` model, and the Testing module exports its own `Tag`, which makes the name
// ambiguous in any file importing both (the public `Sahha` class shadows the module
// name, so `Sahha.Tag` cannot disambiguate either).

/// Inert dead-letter-queue statistics for report-builder tests.
func emptyPersistenceStatistics() -> PersistenceStatistics {
    PersistenceStatistics(
        totalBatches: 0,
        totalItems: 0,
        failedBatches: 0,
        oldestTimestamp: nil,
        retentionDays: 7
    )
}

/// Inert data-log uploader: swallows work, reports an empty queue.
actor NullDataLogUploader: DataLogUploaderProtocol {
    func enqueueLogs(_ logs: [DataLog]) async {}
    func retryPendingUploads() async {}
    func getDLQStatistics() async -> PersistenceStatistics { emptyPersistenceStatistics() }
    func dispose() async {}
}

/// Inert tag uploader: swallows work, reports an empty queue.
actor NullTagUploader: TagUploaderProtocol {
    func enqueueTags(_ tags: [Tag]) async {}
    func retryPendingUploads() async {}
    func getDLQStatistics() async -> PersistenceStatistics { emptyPersistenceStatistics() }
    func dispose() async {}
}
