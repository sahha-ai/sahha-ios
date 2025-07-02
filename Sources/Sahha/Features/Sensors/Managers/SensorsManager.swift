import Foundation

final actor SensorsManager: SensorsManagerProtocol {
    private let logger: LoggerProtocol
    private let userDefaults: UserDefaults
    private let hkManager: HKManagerProtocol

    private let enabledSensorsKey = Constants.UserDefaultsKeys.enabledSensors
    private var enabledSensorsCache: Set<SahhaSensor>

    init(logger: LoggerProtocol, userDefaults: UserDefaults = .standard, hkManager: HKManagerProtocol) {
        self.logger = logger
        self.userDefaults = userDefaults
        self.hkManager = hkManager

        let rawSensors = userDefaults.array(forKey: enabledSensorsKey) as? [String] ?? []
        self.enabledSensorsCache = Set(rawSensors.compactMap { SahhaSensor(rawValue: $0) })
    }

    func resumeSensors() async throws {
        logger.info("Resuming sensors")
        try await hkManager.enableSensors(enabledSensorsCache)
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Sensors")
        }
        let rawSensors = sensors.map { $0.rawValue }
        userDefaults.set(rawSensors, forKey: enabledSensorsKey)
        self.enabledSensorsCache = sensors
        try await hkManager.enableSensors(sensors)
    }

    func getEnabledSensors() async -> Set<SahhaSensor> {
        enabledSensorsCache
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard !sensors.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Sensors")
        }
        return try await hkManager.getSensorStatus(sensors)
    }

    func dispose() async {
        userDefaults.removeObject(forKey: enabledSensorsKey)
        self.enabledSensorsCache = []
    }
}
