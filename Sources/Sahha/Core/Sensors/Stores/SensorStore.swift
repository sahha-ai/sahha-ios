import Foundation

protocol SensorStore: Actor, Disposable {
    func setSensors(_ sensors: Set<SahhaSensor>)
    func getSensors() -> Set<SahhaSensor>
}

final actor SensorStoreImpl: SensorStore {
    private let userDefaults: UserDefaults
    private let enabledSensorsKey = Constants.UserDefaultsKeys.Sensors.enabledSensors
    
    private var sensors: Set<SahhaSensor>
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let rawSensors = userDefaults.array(forKey: enabledSensorsKey) as? [String] ?? []
        self.sensors = Set(rawSensors.compactMap(SahhaSensor.init))
    }
    
    func setSensors(_ sensors: Set<SahhaSensor>) {
        self.sensors = sensors
        let rawSensors = sensors.map { $0.rawValue }
        userDefaults.set(rawSensors, forKey: enabledSensorsKey)
    }
    
    func getSensors() -> Set<SahhaSensor> {
        sensors
    }
    
    func dispose() async {
        sensors.removeAll()
        userDefaults.removeObject(forKey: enabledSensorsKey)
    }
}
