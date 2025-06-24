extension Dictionary {
    func merging(_ other: [Key: Value]) -> [Key: Value] {
        var result = self
        other.forEach { result[$0.key] = $0.value }
        return result
    }

    mutating func merge(_ other: [Key: Value]) {
        other.forEach { self[$0.key] = $0.value }
    }
}
