final actor SensorStore {
    static let shared = SensorStore()

    private let storage = UserDefaultsStorage<Set<String>>(key: "ai.sahha.ios.enabled-sensors")
    private var cached: Set<String> = []

    private init() {
        self.cached = storage.get() ?? []
    }

    func setSensors(_ sensors: Set<SahhaSensor>) {
        let values = Set(sensors.map(\.rawValue))
        cached = values
        storage.set(cached)
    }

    func clearSensors() {
        cached.removeAll()
        storage.set(cached)
    }

    func isEnabled(_ sensor: SahhaSensor) -> Bool {
        cached.contains(sensor.rawValue)
    }

    func getEnabledSensors() -> Set<SahhaSensor> {
        Set(cached.compactMap(SahhaSensor.init(rawValue:)))
    }
}
