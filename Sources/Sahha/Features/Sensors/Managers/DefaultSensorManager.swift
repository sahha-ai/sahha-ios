import Foundation

final class DefaultSensorManager: SensorManager {
    private let sensorStore: SensorStore
    private let observerManager: HKObserverManager
    private let permissionManager: HKPermissionManager
    private let dataLogFetcher: DataLogFetcher
    private let samplesFetcher: SamplesFetcher
    private let statsFetcher: StatsFetcher
    private let logger: Logger

    init(
        sensorStore: SensorStore,
        observerManager: HKObserverManager,
        permissionManager: HKPermissionManager,
        dataLogFetcher: DataLogFetcher,
        samplesFetcher: SamplesFetcher,
        statsFetcher: StatsFetcher,
        logger: Logger
    ) {
        self.sensorStore = sensorStore
        self.observerManager = observerManager
        self.permissionManager = permissionManager
        self.dataLogFetcher = dataLogFetcher
        self.samplesFetcher = samplesFetcher
        self.statsFetcher = statsFetcher
        self.logger = logger
    }

    func enableSensors(_ sensors: Set<SahhaSensor>) async throws {
        let enabledSensors = await sensorStore.getEnabledSensors()
        let sensorsToDisable = enabledSensors.subtracting(sensors)

        if !sensorsToDisable.isEmpty {
            logger.info("Disabling sensors: \(sensorsToDisable.map { $0.rawValue }.joined(separator: ", "))")
            await observerManager.stopObserving(sensors: sensorsToDisable)
        }

        do {
            try await permissionManager.requestPermissions(for: sensors)
            logger.info("Permissions granted for sensors: \(sensors.map { $0.rawValue }.joined(separator: ", "))")
        } catch {
            logger.error("Permission request failed for sensors: \(sensors.map { $0.rawValue }.joined(separator: ", ")), error: \(error)")
            throw error
        }

        do {
            try await observerManager.startObserving(sensors: sensors) { [weak self] sensor in
                do {
                    try await self?.dataLogFetcher.fetchAndProcessSamples(for: sensor)
                } catch {
                    self?.logger.error("Error starting data collection for \(sensor): \(error)")
                }
            }
        } catch {
            logger.error("Failed to start observing sensors: \(sensors.map { $0.rawValue }.joined(separator: ", ")), error: \(error)")
            throw error
        }
    }

    func resumeSensors() async throws {
        let enabledSensors = await sensorStore.getEnabledSensors()

        do {
            try await observerManager.startObserving(sensors: enabledSensors) { [weak self] sensor in
                do {
                    try await self?.dataLogFetcher.fetchAndProcessSamples(for: sensor)
                } catch {
                    self?.logger.error("Error starting data collection for \(sensor): \(error)")
                }
            }
        } catch {
            logger.error("Failed to resume observing sensors: \(enabledSensors.map { $0.rawValue }.joined(separator: ", ")), error: \(error)")
            throw error
        }
    }

    func getSensorStatus(_ sensors: Set<SahhaSensor>) async throws -> SahhaSensorStatus {
        let status = try await permissionManager.permissionStatus(for: sensors)
        return status
    }

    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] {
        let samples = try await samplesFetcher.fetchSamples(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
        return samples
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        let stats = try await statsFetcher.getStats(for: sensor, startDateTime: startDateTime, endDateTime: endDateTime)
        return stats
    }
}
