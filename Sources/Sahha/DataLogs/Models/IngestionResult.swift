enum IngestionResult {
    case success, storageFailed, batchingPaused
}

extension IngestionResult {
    func merge(with other: IngestionResult) -> IngestionResult {
        switch (self, other) {
        case (.storageFailed, _), (_, .storageFailed): return .storageFailed
        case (.batchingPaused, _), (_, .batchingPaused): return .batchingPaused
        default: return .success
        }
    }
}
