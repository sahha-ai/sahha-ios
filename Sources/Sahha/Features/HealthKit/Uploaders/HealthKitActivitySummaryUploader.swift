import HealthKit

final class HealthKitActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    private let permissionsService: HealthKitPermissionsServiceProtocol
    private let anchorStore: HealthKitAnchorDateStoreProtocol
    private let queryService: HealthKitAnchorQueryServiceProtocol
    private let normaliserRegistry: HKSampleToDataLogNormaliserProtocol
    private let dataLogPipeline: DataLogPipelineProtocol
    private let logger: ErrorLoggerProtocol
    private let calendar: Calendar

    init(
        permissionsService: HealthKitPermissionsServiceProtocol,
        anchorStore: HealthKitAnchorDateStoreProtocol,
        queryService: HealthKitAnchorQueryServiceProtocol,
        normaliserRegistry: HKSampleToDataLogNormaliserProtocol,
        dataLogPipeline: DataLogPipelineProtocol,
        logger: ErrorLoggerProtocol,
        calendar: Calendar = .current
    ) {
        self.permissionsService = permissionsService
        self.anchorStore = anchorStore
        self.queryService = queryService
        self.normaliserRegistry = normaliserRegistry
        self.dataLogPipeline = dataLogPipeline
        self.logger = logger
        self.calendar = calendar
    }

    func postInsights() async {
        let sensor: SahhaSensor = .activity_summary

        do {
            guard try await permissionsService.hasPermissions(for: sensor) else { return }

            // Get last anchor date or default to previous month
            let today = Date()
            let startDate: Date
            if let anchorDate = await anchorStore.loadAnchorDate(for: sensor) {
                startDate = anchorDate
            } else {
                startDate = calendar.date(byAdding: .day, value: -31, to: today) ?? today
            }
            let endDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today

            // Only run once per day
            guard !calendar.isDateInToday(startDate), today > startDate else { return }

            // Set today's date as the anchor immediately (to prevent duplication)
            await anchorStore.saveAnchorDate(today, for: sensor)

            guard let sampleType = sensor.hkObjectType as? HKSampleType else { return }
            let predicate = calendarPredicate(from: startDate, to: endDate)
            do {
                let (samples, _) = try await queryService.runAnchorQuery(
                    for: sampleType,
                    predicate: predicate,
                    anchor: nil,
                    limit: HKObjectQueryNoLimit
                )
                guard !samples.isEmpty else { return }

                let logs = samples.flatMap { normaliserRegistry.normalise($0) }
                if !logs.isEmpty {
                    await dataLogPipeline.ingest(logs)
                }
            } catch {
                // Roll back anchor on error
                await anchorStore.saveAnchorDate(startDate, for: sensor)
                throw error
            }
        } catch {
        }
    }

    private func calendarPredicate(from start: Date, to end: Date) -> NSPredicate? {
        let startComponents = calendar.dateComponents([.day, .month, .year], from: start)
        let endComponents = calendar.dateComponents([.day, .month, .year], from: end)
        return HKQuery.predicate(forActivitySummariesBetweenStart: startComponents, end: endComponents)
    }
}
