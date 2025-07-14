struct StatSegmentAccumulator<Key: Hashable> {
    private var storage: [Key: [String: Double]] = [:]

    mutating func insert(_ key: Key, source: String, value: Double) {
        storage[key, default: [:]][source, default: 0] += value
    }

    var segments: [Key: [String: Double]] { storage }
}
