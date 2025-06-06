import Foundation

struct AggregationRule {
    let dataType: String
    let windowSize: TimeInterval
    let function: AggregationFunction
}

enum AggregationFunction: String {
    case avg, sum, min, max
}

// TODO: Set up real configs for data types
enum AggregationConfig {
    static let rules: [AggregationRule] = [
//        AggregationRule(dataType: "heart_rate", windowSize: .minutes(5), function: .avg),
//        AggregationRule(dataType: "steps", windowSize: .minutes(30), function: .sum)
    ]

    static func rule(for dataType: String) -> AggregationRule? {
        rules.first { $0.dataType == dataType }
    }

    static func shouldAggregate(_ log: DataLog) -> Bool {
        rule(for: log.dataType) != nil
    }
}
