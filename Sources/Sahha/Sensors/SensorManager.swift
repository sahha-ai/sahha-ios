import Foundation
import HealthKit

final actor SensorManager {
    static let shared = SensorManager()
    private let hkAuthorization = HKAuthorization()

    private init() {}

    func enableSensors(_ sensors: Set<SahhaSensor>) async -> (String?, SahhaSensorStatus) {
        guard HKHealthStore.isHealthDataAvailable() else {
            return (nil, .unavailable)
        }

        let sampleTypes = sensors.compactMap { $0.hkSampleType }
        guard sampleTypes.isEmpty == false else {
            return ("Health data types not specified", .pending)
        }
        
        let status = await hkAuthorization.requestAuthorization(for: Set(sampleTypes))
        if status == .unnecessary {
            await SensorStore.shared.enableSensors(sensors)
            await HKManager.shared.startSensors(for: Set(sampleTypes))
        }

        return await getSensorStatus(sensors)
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
