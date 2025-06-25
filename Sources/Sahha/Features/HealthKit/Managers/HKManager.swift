final actor HKManager: HKManagerProtocol {
    private let permissionManager: HKPermissionManagerProtocol
    private let queryManager: HKQueryManagerProtocol

    init(permissionManager: HKPermissionManagerProtocol, queryManager: HKQueryManagerProtocol) {
        self.permissionManager = permissionManager
        self.queryManager = queryManager
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let sampleTypes = sensors.compactMap { SensorMapper.objectType(for: $0) }
        let sampleTypeSet = Set(sampleTypes)
        
        print("Enabling sensors...")

        try await permissionManager.requestPermissions(for: sampleTypeSet)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for sampleType in sampleTypeSet {
                group.addTask {
                    do {
                        try await self.queryManager.enableBackgroundDelivery(for: sampleType)
                    } catch {
                        let sensor = SensorMapper.sensor(for: sampleType)
                        print("Failed to enable background delivery for \(sensor?.rawValue ?? "unknown sensor"): \(error)")
                    }
                    await self.queryManager.startObserverQuery(for: sampleType)
                }
            }
            for try await _ in group {}
        }
    }
}
