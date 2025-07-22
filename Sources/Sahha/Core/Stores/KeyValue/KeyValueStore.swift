protocol KeyValueStore: Actor {
    func set<T: Codable>(_ value: T, forKey key: String)
    func get<T: Codable>(_ key: String) -> T?
    func remove(_ key: String)
}
