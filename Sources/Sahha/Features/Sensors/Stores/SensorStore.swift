actor SensorStore: SensorStoreProtocol {
    private let storage: UserDefaultsStorageProtocol
    private let key: String
    
    private var sensors: Set<SahhaSensor>?
    
    init(
        storage: UserDefaultsStorageProtocol = UserDefaultsStorage(),
        key: String = StorageKeys.UserDefaults.sensors
    ) {
        self.storage = storage
        self.key = key
        
        self.sensors = try? storage.object(forKey: key)
    }
    
    func setSensors(_ sensors: Set<SahhaSensor>) throws {
        try storage.setObject(sensors, forKey: key)
        self.sensors = sensors
    }
    
    func getSensors() throws -> Set<SahhaSensor> {
        if let sensors { return sensors }
        self.sensors = try storage.object(forKey: key)
        return self.sensors ?? []
    }
    
    func hasSensor(_ sensor: SahhaSensor) -> Bool {
        sensors?.contains(sensor) ?? false
    }
}
