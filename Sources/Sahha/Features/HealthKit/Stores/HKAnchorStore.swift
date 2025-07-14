import HealthKit

protocol HKAnchorStore: Actor, Disposable {
    func getAnchor(for identifier: String) -> HKQueryAnchor?
    func saveAnchor(_ anchor: HKQueryAnchor, for identifier: String)
}

final actor HKAnchorStoreImpl: HKAnchorStore {
    private let userDefaults: UserDefaults
    private let key = Constants.UserDefaultsKeys.HealthKit.anchors

    private var anchors: [String: HKQueryAnchor] = [:]

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        if let dataDict = userDefaults.dictionary(forKey: key) as? [String: Data] {
            self.anchors = dataDict.compactMapValues { data in
                try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
            }
        }
    }

    func getAnchor(for identifier: String) -> HKQueryAnchor? {
        anchors[identifier]
    }

    func saveAnchor(_ anchor: HKQueryAnchor, for identifier: String) {
        anchors[identifier] = anchor
        var anchorDataDict = (userDefaults.dictionary(forKey: key) as? [String: Data]) ?? [:]
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            anchorDataDict[identifier] = data
            UserDefaults.standard.set(anchorDataDict, forKey: key)
        }
    }

    func dispose() async {
        anchors.removeAll()
        userDefaults.removeObject(forKey: key)
    }
}
