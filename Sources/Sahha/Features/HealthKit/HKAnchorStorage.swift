import HealthKit

protocol HKAnchorStorageProtocol {
    func getAnchor(for type: HKSampleType) -> HKQueryAnchor?
    func setAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType)
    func deleteAnchors()
}

struct HKAnchorStorage: HKAnchorStorageProtocol {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func getAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        let key = "anchor_\(type.identifier)"
        guard let data = userDefaults.data(forKey: key),
              let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) else {
            return nil
        }
        return anchor
    }

    func setAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        let key = "anchor_\(type.identifier)"
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: key)
        }
    }

    func deleteAnchors() {
        let allKeys = userDefaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("anchor_") }
        allKeys.forEach { userDefaults.removeObject(forKey: $0) }
    }
}
