import Foundation

final actor SensorsManager: SensorsManagerProtocol, LifecycleHandler {
   

    private let userDefaults: UserDefaults
    private let hkManager: HKManagerProtocol

    private let enabledSensorsKey = Constants.UserDefaultsKeys.enabledSensors

    init(userDefaults: UserDefaults = .standard, hkManager: HKManagerProtocol) {
        self.userDefaults = userDefaults
        self.hkManager = hkManager
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async {
        let rawSensors = sensors.map { $0.rawValue }
        userDefaults.set(rawSensors, forKey: enabledSensorsKey)
        
        do {
            try await hkManager.enableSensors(sensors)
        } catch {
            print("Failed to enable sensors: \(error.localizedDescription)")
        }
    }
    
    func handleLifecycleEvent(event: LifecycleEvent) async {
    
    }

    func getSensorStatus(_ sensor: Set<SahhaSensor>) async -> SahhaSensorStatus {
        return .pending  // TODO: Implementation
    }

    func dispose() async {
        userDefaults.removeObject(forKey: enabledSensorsKey)
    }
}
