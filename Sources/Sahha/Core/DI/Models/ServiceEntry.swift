struct ServiceEntry {
    let factory: @Sendable (DIContainer) async throws -> any Sendable
    let lifetime: ServiceLifetime
    var instance: Any?
}
