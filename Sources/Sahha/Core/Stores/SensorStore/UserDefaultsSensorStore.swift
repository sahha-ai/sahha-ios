import Foundation

final actor UserDefaultsSensorStore: SensorStore {
    private let defaults: UserDefaults
    private let storageKey = StorageKeys.enabledSensors

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func setEnabledSensors(_ sensors: Set<SahhaSensor>) {
        let rawValues = sensors.map { $0.rawValue }
        defaults.set(rawValues, forKey: storageKey)
    }

    func getEnabledSensors() -> Set<SahhaSensor> {
        guard let rawValues = defaults.array(forKey: storageKey) as? [String] else {
            return []
        }
        let sensors = rawValues.compactMap { SahhaSensor(rawValue: $0) }
        return Set(sensors)
    }

    func dispose() async {
        defaults.removeObject(forKey: storageKey)
    }
}
