import HealthKit

protocol SampleQueryHandlerProtocol: Actor {
    func executeSampleQuery(for type: HKSampleType) async throws -> [SahhaSample]
}

final actor SampleQueryHandler: SampleQueryHandlerProtocol {
    private let healthStore: HKHealthStore
    private let logger: LoggerProtocol

    init(
        healthStore: HKHealthStore = HKHealthStore(),
        logger: LoggerProtocol,
    ) {
        self.healthStore = healthStore
        self.logger = logger
    }
    
    func executeSampleQuery(for type: HKSampleType) async throws -> [SahhaSample] {
        fatalError("Not implemented")
    }
}
