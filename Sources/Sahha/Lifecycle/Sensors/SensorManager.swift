import Foundation
import HealthKit

final actor SensorManager {
    static let shared = SensorManager()
    private let hkAuthorization = HKAuthorization()

    private init() {}

    func enableSensors(_ sensors: Set<SahhaSensor>) async -> (String?, SahhaSensorStatus) {
        guard HKHealthStore.isHealthDataAvailable() else {
            SahhaLogger.error("HealthKit is unavailable")
            return (nil, .unavailable)
        }

        let sampleTypes = sensors.compactMap { $0.hkSampleType }
        guard sampleTypes.isEmpty == false else {
            SahhaLogger.error("Health data types not specified")
            return ("Health data types not specified", .pending)
        }
        
        let status = await hkAuthorization.requestAuthorization(for: Set(sampleTypes))
        if status == .unnecessary {
            SahhaLogger.info("Setting up sensors...")
            await SensorStore.shared.setSensors(sensors)
            await HKManager.shared.startSensors()
        }

        return await getSensorStatus(sensors)
    }
    
    func stopSensors() async {
        await HKManager.shared.reset()
        await SensorStore.shared.clearSensors()
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async -> (String?, SahhaSensorStatus) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (nil, .unavailable)
        }

        let sampleTypes = sensors.compactMap { $0.hkSampleType }
        guard sampleTypes.isEmpty == false else {
            return ("Health data types not specified", .pending)
        }

        let status = await hkAuthorization.statusForAuthorizationRequest(for: Set(sampleTypes))
        let sensorStatus: SahhaSensorStatus = (status == .unnecessary) ? .enabled : .pending
        return (nil, sensorStatus)
    }
}
