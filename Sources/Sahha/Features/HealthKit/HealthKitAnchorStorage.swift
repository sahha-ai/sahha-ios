import HealthKit

protocol HealthKitAnchorStorageProtocol {
    func getAnchor(for type: HKSampleType) -> HKQueryAnchor?
    func setAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType)
    func deleteAnchors()
}

struct HealthKitAnchorStorage: HealthKitAnchorStorageProtocol {
    private let storage: any UserDefaultsStorageProtocol<[String: Data]>
    
    init(storage: any UserDefaultsStorageProtocol<[String: Data]>) {
        self.storage = storage
    }
    
    func getAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        guard let data = storage.get()?[type.identifier],
              let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) else {
            return nil
        }
        return anchor
    }
    
    func setAnchor(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        var anchors = storage.get() ?? [:]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            anchors[type.identifier] = data
        }
        storage.set(anchors)
    }
    
    func deleteAnchors() {
        storage.delete()
    }
}
