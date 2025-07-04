import Foundation

protocol SensorsManagerProtocol: Actor, DisposableAsync {
    func resumeSensors() async throws
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func getEnabledSensors() async -> Set<SahhaSensor>
}

final actor SensorsManager: SensorsManagerProtocol {
    private let logger: LoggerProtocol
    private let userDefaults: UserDefaults
    private let hkManager: HealthKitManagerProtocol

    private let enabledSensorsKey = Constants.UserDefaultsKeys.enabledSensors
    private var enabledSensorsCache: Set<SahhaSensor>

    init(logger: LoggerProtocol, userDefaults: UserDefaults = .standard, hkManager: HealthKitManagerProtocol) {
        self.logger = logger
        self.userDefaults = userDefaults
        self.hkManager = hkManager

        let rawSensors = userDefaults.array(forKey: enabledSensorsKey) as? [String] ?? []
        self.enabledSensorsCache = Set(rawSensors.compactMap { SahhaSensor(rawValue: $0) })
    }

    func resumeSensors() async throws {
        logger.info("Resuming sensors")
        try await hkManager.resumeSensors(enabledSensorsCache)
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard !sensors.isEmpty else {
            throw ValidationError.emptyCollection(collection: "Sensors")
        }
        let sensorsToDisable = enabledSensorsCache.subtracting(sensors)
        try await hkManager.disableSensors(sensorsToDisable)
        try await hkManager.enableSensors(sensors)
        let rawSensors = sensors.map { $0.rawValue }
        userDefaults.set(rawSensors, forKey: enabledSensorsKey)
        self.enabledSensorsCache = sensors
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
