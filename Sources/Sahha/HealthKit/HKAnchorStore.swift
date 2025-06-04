import Foundation
import HealthKit

final actor HKAnchorStore {
    static let shared = HKAnchorStore()

    private let anchorKeyPrefix = "ai.sahha.ios.hk-anchor-"
    private let defaults = UserDefaults.standard

    private init() {}

    func saveAnchor(_ anchor: HKQueryAnchor, for sampleType: HKSampleType) {
        let key = anchorKey(for: sampleType)
        let store = ArchivedUserDefaultsStorage<HKQueryAnchor>(key: key, userDefaults: defaults)
        store.set(anchor)
    }

    func loadAnchor(for sampleType: HKSampleType) -> HKQueryAnchor? {
        let key = anchorKey(for: sampleType)
        let store = ArchivedUserDefaultsStorage<HKQueryAnchor>(key: key, userDefaults: defaults)
        return store.get()
    }

    func removeAnchor(for sampleType: HKSampleType) {
        let key = anchorKey(for: sampleType)
        let store = ArchivedUserDefaultsStorage<HKQueryAnchor>(key: key, userDefaults: defaults)
        store.delete()
    }

    func clearAllAnchors() {
        for key in defaults.dictionaryRepresentation().keys
        where key.starts(with: anchorKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    private func anchorKey(for sampleType: HKSampleType) -> String {
        return anchorKeyPrefix + sampleType.identifier
    }
}
