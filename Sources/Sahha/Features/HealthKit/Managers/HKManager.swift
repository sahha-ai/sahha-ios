import Foundation
import HealthKit

protocol HKManager: Sendable {
    func enableSensors(_ sensors: Set<SahhaSensor>) async throws
    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus
    func resumeSensors() async
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample]
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}

final class HKManagerImpl: HKManager {
    private let healthStore: HKHealthStore
    private let authorizationManager: HKAuthorizationManager
    private let observerQueryHandler: HKObserverQueryHandler
    private let sensorStore: SensorStore
    private let sampleProvider: SampleProvider
    private let statsProvider: StatsProvider

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        authorizationManager: HKAuthorizationManager,
        observerQueryHandler: HKObserverQueryHandler,
        sensorStore: SensorStore,
        sampleProvider: SampleProvider,
        statsProvider: StatsProvider
    ) {
        self.healthStore = healthStore
        self.authorizationManager = authorizationManager
        self.observerQueryHandler = observerQueryHandler
        self.sensorStore = sensorStore
        self.sampleProvider = sampleProvider
        self.statsProvider = statsProvider
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SensorError.healthkitUnavailable
        }
        
        let enabledSensors = await sensorStore.getSensors()
        let sensorsToDisable = enabledSensors.subtracting(sensors)

        let objectTypes = Set(sensors.compactMap { SensorMapper.metadata(for: $0)?.hkObjectType })

        await disableSensors(sensorsToDisable)

        try await authorizationManager.requestAuthorization(for: objectTypes)

        await withTaskGroup(of: Void.self) { group in
            for sensor in sensors {
                group.addTask {
                    if let metadata = SensorMapper.metadata(for: sensor),
                        let sampleType = metadata.hkObjectType as? HKSampleType
                    {
                        await self.observerQueryHandler.startObserver(for: sampleType)
                    }
                }
            }
        }

        await sensorStore.setSensors(sensors)
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SensorError.healthkitUnavailable
        }

        let objectTypes = Set(sensors.compactMap { SensorMapper.metadata(for: $0)?.hkObjectType })

        guard !objectTypes.isEmpty else {
            return .unavailable  // TODO
        }

        let status = try await authorizationManager.getAuthorizationStatus(for: objectTypes)

        if case .unnecessary = status {
            return .enabled
        }

        return .pending
    }

    func resumeSensors() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        let enabledSensors = await sensorStore.getSensors()
        
        print("Resuming sensors")

        await withTaskGroup(of: Void.self) { group in
            for sensor in enabledSensors {
                group.addTask {
                    if let metadata = SensorMapper.metadata(for: sensor),
                        let sampleType = metadata.hkObjectType as? HKSampleType
                    {
                        await self.observerQueryHandler.startObserver(for: sampleType)
                    }
                }
            }
        }
    }

    private func disableSensors(_ sensors: Set<SahhaSensor>) async {
        guard HKHealthStore.isHealthDataAvailable() else {
            return
        }

        await withThrowingTaskGroup(of: Void.self) { group in
            for sensor in sensors {
                group.addTask {
                    if let metadata = SensorMapper.metadata(for: sensor),
                        let sampleType = metadata.hkObjectType as? HKSampleType
                    {
                        await self.observerQueryHandler.stopObserver(for: sampleType)
                    }
                }
            }
        }
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SensorError.healthkitUnavailable
        }

        return try await sampleProvider.getSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SensorError.healthkitUnavailable
        }

        return try await statsProvider.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
    }
}
