final actor SensorStore {
    static let shared = SensorStore()
    
    private let storage = UserDefaultsStorage<Set<String>>(key: "ai.sahha.ios.enabled-sensors")
    private var cached: Set<String> = []
    
    private init() {
        self.cached = storage.get() ?? []
    }
    
    func enableSensor(_ sensor: SahhaSensor) {
          cached.insert(sensor.rawValue)
          storage.set(cached)
      }

      func enableSensors(_ sensors: Set<SahhaSensor>) {
          let newValues = sensors.map(\.rawValue)
          cached.formUnion(newValues)
          storage.set(cached)
      }

      func disableSensor(_ sensor: SahhaSensor) {
          cached.remove(sensor.rawValue)
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
