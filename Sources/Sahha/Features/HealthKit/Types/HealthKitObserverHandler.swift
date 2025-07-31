import HealthKit

typealias HealthKitObserverHandler = @Sendable (SahhaSensor, HKSampleType) async -> Void
