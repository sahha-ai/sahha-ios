protocol BatchProcessor<Item>: Actor, Disposable {
    associatedtype Item: Sendable

    func enqueue(_ item: Item, for key: String) async throws
    func enqueue(_ items: [Item], for key: String) async throws
    func waitTilProcessed(for key: String) async
}
