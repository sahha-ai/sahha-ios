import Foundation

protocol StatsProvider: Sendable {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat]
}

final class StatsProviderImpl: StatsProvider {
    private let sleepStatsProvider: SleepStatsProvider
    private let exerciseStatsProvider: ExerciseStatsProvider
    private let quantityStatsProvider: QuantityStatsProvider

    init(
        sleepStatsProvider: SleepStatsProvider,
        exerciseStatsProvider: ExerciseStatsProvider,
        quantityStatsProvider: QuantityStatsProvider
    ) {
        self.sleepStatsProvider = sleepStatsProvider
        self.exerciseStatsProvider = exerciseStatsProvider
        self.quantityStatsProvider = quantityStatsProvider
    }

    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] {
        switch sensor {
        case .sleep:
            return try await sleepStatsProvider.getStats(
                from: startDateTime,
                to: endDateTime,
                periodicity: .daily
            )
        case .exercise:
            return try await exerciseStatsProvider.getStats(
                from: startDateTime,
                to: endDateTime,
                periodicity: .daily
            )
        default:
            return try await quantityStatsProvider.getStats(
                for: sensor,
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                periodicity: .daily
            )
        }
    }
}
