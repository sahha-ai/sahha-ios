import HealthKit

// ─── Symptom Enums ───────────────────────────────────────────────────────────
//
// String values are shared across iOS (HealthKit) and Android (Health Connect)
// so that the normalised value is platform-agnostic.
//
// Do not remove entries — values are part of the data contract.
// Append new entries at the end of each enum only.

enum SeverityEnum: String {
    case unknown = "unknown"
    case notPresent  = "not_present"
    case mild        = "mild"
    case moderate    = "moderate"
    case severe      = "severe"

    var value: String { rawValue }
}

// ─── HealthKit → Platform-Agnostic Mappings ──────────────────────────────────

extension HKCategoryValueSeverity {
    var severityValue: String {
        switch self {
        case .unspecified: return SeverityEnum.unknown.value
        case .notPresent:  return SeverityEnum.notPresent.value
        case .mild:        return SeverityEnum.mild.value
        case .moderate:    return SeverityEnum.moderate.value
        case .severe:      return SeverityEnum.severe.value
        @unknown default:  return SeverityEnum.unknown.value
        }
    }
}
