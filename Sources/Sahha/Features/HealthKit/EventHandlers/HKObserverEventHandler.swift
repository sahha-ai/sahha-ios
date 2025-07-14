import HealthKit

protocol HKObserverEventHandler: Sendable {
    func handleObserverEvent(for sampleType: HKSampleType) async
}

final class HKObserverEventHandlerImpl: HKObserverEventHandler {
    private let anchorQueryHandler: HKAnchorQueryHandler
    private let anchorStore: HKAnchorStore
    private let normaliser: Normaliser<HKSample, DataLog>
    private let dataLogProcessor: DataLogProcessor
    private let logger: Logger

    init(
        anchorQueryHandler: HKAnchorQueryHandler,
        anchorStore: HKAnchorStore,
        normaliser: Normaliser<HKSample, DataLog>,
        dataLogProcessor: DataLogProcessor,
        logger: Logger
    ) {
        self.anchorQueryHandler = anchorQueryHandler
        self.anchorStore = anchorStore
        self.normaliser = normaliser
        self.dataLogProcessor = dataLogProcessor
        self.logger = logger
    }

    func handleObserverEvent(for sampleType: HKSampleType) async {
        let id = sampleType.identifier

        repeat {
            do {
                let (samples, newAnchor) = try await anchorQueryHandler.fetchAnchoredUpdates(
                    for: sampleType,
                    predicate: nil,
                    limit: 1000
                )

                if samples.isEmpty {
                    break
                }

                let dataLogs = samples.flatMap(normaliser.normalise)
                
                print("Normalised \(dataLogs.count) data logs")

                await dataLogProcessor.enqueue(dataLogs)

                if let newAnchor {
                    await anchorStore.saveAnchor(newAnchor, for: id)
                }
            } catch {
                logger.error("Failed to handle observer event for \(id): \(error.localizedDescription)")
                break
            }
        } while true
    }
}
