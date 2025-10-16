import HealthKit

protocol HealthKitAnchorDateStoreProtocol: Actor {
    func saveAnchorDate(_ date: Date, forKey key: String)
    func loadAnchorDate(forKey key: String) -> Date?
}

extension HealthKitAnchorDateStoreProtocol {
    func saveAnchorDate(_ date: Date, for sensor: SahhaSensor) {
        saveAnchorDate(date, forKey: sensor.rawValue)
    }
    func loadAnchorDate(for sensor: SahhaSensor) -> Date? {
        loadAnchorDate(forKey: sensor.rawValue)
    }
}
