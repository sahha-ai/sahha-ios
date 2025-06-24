protocol DataLogAggregationManagerProtocol: DisposableAsync {
    func aggregate(_ input: [any DataLogType]) async throws -> [any DataLogType]
}

actor DataLogAggregationManager: DataLogAggregationManagerProtocol {
    
    func aggregate(_ input: [any DataLogType]) async throws -> [any DataLogType] {
        // Stub: Pass through input unchanged
        return input
    }
    
    func dispose() async {
        // TODO
    }
}
