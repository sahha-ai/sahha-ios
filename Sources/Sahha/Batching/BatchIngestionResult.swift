enum BatchIngestionResult {
    case success, storageFailed, batchingPaused
}

extension BatchIngestionResult {
    func merge(with other: BatchIngestionResult) -> BatchIngestionResult {
        switch (self, other) {
        case (.storageFailed, _), (_, .storageFailed): return .storageFailed
        case (.batchingPaused, _), (_, .batchingPaused): return .batchingPaused
        default: return .success
        }
    }
}
