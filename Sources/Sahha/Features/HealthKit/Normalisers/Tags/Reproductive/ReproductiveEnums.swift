import HealthKit

// ─── Reproductive Enums ───────────────────────────────────────────────────────
//
// Ordinal values are shared across iOS (HealthKit) and Android (Health Connect)
// so that the normalised value is platform-agnostic.
//
// Do not reorder or remove entries — ordinals are part of the data contract.
// Append new entries at the end of each enum only.

enum OvulationTestEnum: Double {
    case inconclusive = 0   // HC: RESULT_INCONCLUSIVE / HK: indeterminate
    case negative     = 1   // HC: RESULT_NEGATIVE     / HK: negative
    case high         = 2   // HC: RESULT_HIGH         / HK: estrogenSurge
    case positive     = 3   // HC: RESULT_POSITIVE     / HK: luteinizingHormoneSurge

    var value: Double { rawValue }
}

enum MenstrualFlowEnum: Double {
    case unknown = 0    // HK: unspecified
    case none    = 1    // HK: notPresent
    case light   = 2
    case medium  = 3
    case heavy   = 4

    var value: Double { rawValue }
}

enum CervicalMucusEnum: Double {
    case unknown   = 0
    case dry       = 1
    case sticky    = 2
    case creamy    = 3
    case watery    = 4
    case eggWhite  = 5
    case unusual   = 6  // Android Health Connect only — no HealthKit equivalent

    var value: Double { rawValue }
}

enum SexualActivityEnum: Double {
    case unknown     = 0
    case protected_  = 1    // `protected` is a Swift keyword, so suffixed with _
    case unprotected = 2

    var value: Double { rawValue }
}

enum PregnancyTestEnum: Double {
    case inconclusive = 0   // HK: indeterminate
    case negative     = 1
    case positive     = 2

    var value: Double { rawValue }
}

enum ProgesteroneTestEnum: Double {
    case inconclusive = 0
    case negative     = 1
    case positive     = 2

    var value: Double { rawValue }
}

enum ContraceptiveEnum: Double {
    case unknown          = 0
    case implant          = 1
    case injection        = 2
    case intravaginalRing = 3
    case iud              = 4
    case oral             = 5
    case patch            = 6

    var value: Double { rawValue }
}

// ─── HealthKit → Platform-Agnostic Mappings ──────────────────────────────────

extension HKCategoryValueMenstrualFlow {
    var menstrualFlowValue: Double {
        switch rawValue {
        case 1: return MenstrualFlowEnum.unknown.value    // unspecified
        case 5: return MenstrualFlowEnum.none.value       // none (flow explicitly absent)
        case 2: return MenstrualFlowEnum.light.value      // light
        case 3: return MenstrualFlowEnum.medium.value     // medium
        case 4: return MenstrualFlowEnum.heavy.value      // heavy
        default: return MenstrualFlowEnum.unknown.value
        }
    }
}

extension HKCategoryValueOvulationTestResult {
    var ovulationTestValue: Double {
        switch self {
        case .indeterminate:           return OvulationTestEnum.inconclusive.value
        case .negative:                return OvulationTestEnum.negative.value
        case .estrogenSurge:           return OvulationTestEnum.high.value
        case .luteinizingHormoneSurge: return OvulationTestEnum.positive.value
        @unknown default:              return OvulationTestEnum.inconclusive.value
        }
    }
}

extension HKCategoryValueCervicalMucusQuality {
    var cervicalMucusValue: Double {
        switch self {
        case .dry:            return CervicalMucusEnum.dry.value
        case .sticky:         return CervicalMucusEnum.sticky.value
        case .creamy:         return CervicalMucusEnum.creamy.value
        case .watery:         return CervicalMucusEnum.watery.value
        case .eggWhite:       return CervicalMucusEnum.eggWhite.value
        @unknown default:     return CervicalMucusEnum.unknown.value
        }
    }
}

extension HKCategoryValuePregnancyTestResult {
    var pregnancyTestValue: Double {
        switch self {
        case .indeterminate: return PregnancyTestEnum.inconclusive.value
        case .negative:      return PregnancyTestEnum.negative.value
        case .positive:      return PregnancyTestEnum.positive.value
        @unknown default:    return PregnancyTestEnum.inconclusive.value
        }
    }
}
