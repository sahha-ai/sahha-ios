extension Array where Element: Sendable {
    func concurrentCompactMap<T: Sendable>(
        _ transform: @Sendable @escaping (Element) async -> T?
    ) async -> [T] {
        await withTaskGroup(of: T?.self) { group in
            for element in self {
                group.addTask { @Sendable in
                    await transform(element)
                }
            }
            
            var results: [T] = []
            for await result in group {
                if let value = result {
                    results.append(value)
                }
            }
            
            return results
        }
    }
    func partitioned(by condition: (Element) -> Bool) -> (matching: [Element], nonMatching: [Element]) {
        var matching: [Element] = []
        var nonMatching: [Element] = []
        
        for element in self {
            if condition(element) {
                matching.append(element)
            } else {
                nonMatching.append(element)
            }
        }
        
        return (matching, nonMatching)
    }
}
