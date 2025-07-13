import HealthKit

protocol PropertyExtractor {
    func extract(from sample: HKSample) -> [String: String]?
}
