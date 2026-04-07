import HealthKit

final class SensorProbeLifecycleListener: LifecycleListener, @unchecked Sendable {
    private let sensorStore: SensorStoreProtocol
    private let sampleQueryService: HealthKitSampleQueryServiceProtocol
    private let logger: ErrorLoggerProtocol

    init(
        sensorStore: SensorStoreProtocol,
        sampleQueryService: HealthKitSampleQueryServiceProtocol,
        logger: ErrorLoggerProtocol
    ) {
        self.sensorStore = sensorStore
        self.sampleQueryService = sampleQueryService
        self.logger = logger
    }

    func handleLifecycleEvent(_ event: LifecycleEvent) async {
        await runProbe()
    }

    private func runProbe() async {
        let enabledSensors: Set<SahhaSensor>
        do {
            enabledSensors = try await sensorStore.getSensors()
        } catch {
            return
        }

        guard !enabledSensors.isEmpty else { return }

        var statuses: [SahhaSensor: SahhaSensorStatus] = [:]

        for sensor in enabledSensors {
            guard let sampleType = sensor.hkSampleType else { continue }

            do {
                let predicate = HKQuery.predicateForSamples(
                    withStart: Calendar.current.date(byAdding: .hour, value: -24, to: Date()),
                    end: Date(),
                    options: .strictStartDate
                )
                let samples = try await sampleQueryService.runSampleQuery(
                    for: sampleType,
                    predicate: predicate,
                    limit: 1,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                )
                statuses[sensor] = samples.isEmpty ? .indeterminate : .enabled
            } catch {
                statuses[sensor] = .indeterminate
            }
        }

        await sensorStore.setSensorStatuses(statuses)
    }
}
