protocol StorageProtocol {
    associatedtype T: Codable

    func get() -> T?
    func set(_ value: T) -> Bool
    func delete() -> Bool
}
