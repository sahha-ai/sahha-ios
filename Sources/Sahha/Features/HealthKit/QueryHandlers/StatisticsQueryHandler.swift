import HealthKit

protocol StatisticsQueryHandlerProtocol: Actor {
    func executeStatisticsQuery(for type: HKSampleType) async throws -> [SahhaStat]
}

final actor StatisticsQueryHandler: StatisticsQueryHandlerProtocol {
    private let healthStore: HKHealthStore
    private let logger: LoggerProtocol

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: LoggerProtocol,
    ) {
        self.healthStore = healthStore
        self.logger = logger
    }
    
    func executeStatisticsQuery(for type: HKSampleType) async throws -> [SahhaStat] {
        fatalError("Not implemented")
    }
}
