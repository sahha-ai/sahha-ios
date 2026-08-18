import Foundation

actor SensorStore: SensorStoreProtocol, Disposable {
    private let storage: UserDefaultsStorageProtocol
    private let key: String

    /// Canonical cached set; nil until the first read resolves. Every resolve
    /// path assigns it — including for an absent key — so reads never hit
    /// storage twice.
    private var sensors: Set<SahhaSensor>?
    private var sensorStatuses: [SahhaSensor: SahhaSensorStatus] = [:]
    private var pendingAnomaly: SensorStoreAnomaly?

    init(
        storage: UserDefaultsStorageProtocol = UserDefaultsStorage(),
        key: String = StorageKeys.UserDefaults.sensors
    ) {
        self.storage = storage
        self.key = key
        // No init-time read: the store resolves lazily on first access, so an
        // anomaly in persisted state is latched where the authenticated
        // bring-up can drain and post it rather than firing pre-auth and being
        // lost.
    }

    func setSensors(_ sensors: Set<SahhaSensor>) throws {
        try storage.setObject(sensors, forKey: key)
        self.sensors = sensors
    }

    func getSensors() throws -> Set<SahhaSensor> {
        resolve()
    }

    func hasSensor(_ sensor: SahhaSensor) -> Bool {
        // Routes through the same lenient read as getSensors: a cache-only
        // check would report every sensor absent until something else resolved
        // the store, breaking demographics and device-lock gating.
        resolve().contains(sensor)
    }

    func setSensorStatuses(_ statuses: [SahhaSensor: SahhaSensorStatus]) {
        sensorStatuses = statuses
    }

    func getSensorStatuses() -> [SahhaSensor: SahhaSensorStatus] {
        sensorStatuses
    }

    func drainPendingAnomaly() -> SensorStoreAnomaly? {
        defer { pendingAnomaly = nil }
        return pendingAnomaly
    }

    func dispose() {
        storage.removeObject(forKey: key)
        sensors = nil
        sensorStatuses = [:]
        pendingAnomaly = nil
    }

    /// The whole read → map → compare → rewrite → cache sequence in one
    /// non-async actor method: no suspension points, so concurrent first reads
    /// cannot interleave and the rewrite and anomaly latch happen at most once.
    private func resolve() -> Set<SahhaSensor> {
        if let sensors { return sensors }

        guard let raw = storage.get(forKey: key) else {
            sensors = []
            return []
        }

        guard let data = raw as? Data else {
            // Not SDK-shaped: never rewritten, deleted, or overwritten. Only
            // the type name is reported, never the value.
            pendingAnomaly = .foreignValue(typeName: String(describing: type(of: raw)))
            sensors = []
            return []
        }

        guard let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
            pendingAnomaly = .undecodableData(byteCount: data.count)
            sensors = []
            return []
        }

        var mapped: Set<SahhaSensor> = []
        var renamed: [String] = []
        var unknown: [String] = []
        for rawValue in rawValues {
            if let sensor = SahhaSensor(rawValue: rawValue) {
                mapped.insert(sensor)
            } else if let sensor = SahhaSensor.legacyToCurrentSensor[rawValue] {
                mapped.insert(sensor)
                renamed.append(rawValue)
            } else {
                unknown.append(rawValue)
            }
        }

        if mapped.isEmpty, !rawValues.isEmpty {
            // All-unknown guard: nothing survived the mapping, so this state
            // most likely belongs to a newer SDK after a downgrade. Report and
            // return empty, but leave storage untouched — rewriting would
            // destroy the newer SDK's state.
            pendingAnomaly = .allUnknownValues(unknown.sorted())
            sensors = []
            return []
        }

        // Set-based comparison, never byte-based: encoding order of a Set is
        // nondeterministic, so equal sets can have different bytes.
        if Set(rawValues) != Set(mapped.map(\.rawValue)) {
            // Self-heal: rewrite in canonical form. A failed rewrite is not
            // fatal — the next store construction repeats the resolve.
            try? storage.setObject(mapped, forKey: key)
        }

        if !renamed.isEmpty || !unknown.isEmpty {
            pendingAnomaly = .healedValues(renamed: renamed.sorted(), droppedUnknown: unknown.sorted())
        }

        sensors = mapped
        return mapped
    }
}
