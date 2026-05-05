import HealthKit

// ─── Reproductive Enums ───────────────────────────────────────────────────────
//
// String values are shared across iOS (HealthKit) and Android (Health Connect)
// so that the normalised value is platform-agnostic.
//
// Do not remove entries — values are part of the data contract.
// Append new entries at the end of each enum only.

enum OvulationTestEnum: String {
    case inconclusive = "inconclusive"   // HC: RESULT_INCONCLUSIVE / HK: indeterminate
    case negative     = "negative"       // HC: RESULT_NEGATIVE     / HK: negative
    case high         = "high"           // HC: RESULT_HIGH         / HK: estrogenSurge
    case positive     = "positive"       // HC: RESULT_POSITIVE     / HK: luteinizingHormoneSurge

    var value: String { rawValue }
}

enum MenstrualFlowEnum: String {
    case unknown = "unknown"    // HK: unspecified / notPresent
    case light   = "light"
    case medium  = "medium"
    case heavy   = "heavy"

    var value: String { rawValue }
}

enum CervicalMucusEnum: String {
    case unknown   = "unknown"
    case dry       = "dry"
    case sticky    = "sticky"
    case creamy    = "creamy"
    case watery    = "watery"
    case eggWhite  = "egg_white"
    case unusual   = "unusual"  // Android Health Connect only — no HealthKit equivalent

    var value: String { rawValue }
}

enum SexualActivityEnum: String {
    case unknown     = "unknown"
    case protected_  = "protected"    // `protected` is a Swift keyword, so suffixed with _
    case unprotected = "unprotected"

    var value: String { rawValue }
}

enum PregnancyTestEnum: String {
    case inconclusive = "inconclusive"   // HK: indeterminate
    case negative     = "negative"
    case positive     = "positive"

    var value: String { rawValue }
}

enum ProgesteroneTestEnum: String {
    case inconclusive = "inconclusive"
    case negative     = "negative"
    case positive     = "positive"

    var value: String { rawValue }
}

enum ContraceptiveEnum: String {
    case unknown          = "unknown"
    case implant          = "implant"
    case injection        = "injection"
    case intravaginalRing = "intravaginal_ring"
    case iud              = "iud"
    case oral             = "oral"
    case patch            = "patch"

    var value: String { rawValue }
}

// ─── HealthKit → Platform-Agnostic Mappings ──────────────────────────────────

extension HKCategoryValueMenstrualFlow {
    var menstrualFlowValue: String {
        switch rawValue {
        case 1: return MenstrualFlowEnum.unknown.value    // unspecified
        case 5: return MenstrualFlowEnum.unknown.value    // notPresent (collapsed to unknown)
        case 2: return MenstrualFlowEnum.light.value      // light
        case 3: return MenstrualFlowEnum.medium.value     // medium
        case 4: return MenstrualFlowEnum.heavy.value      // heavy
        default: return MenstrualFlowEnum.unknown.value
        }
    }
}

extension HKCategoryValueOvulationTestResult {
    var ovulationTestValue: String {
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
    var cervicalMucusValue: String {
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
    var pregnancyTestValue: String {
        switch self {
        case .indeterminate: return PregnancyTestEnum.inconclusive.value
        case .negative:      return PregnancyTestEnum.negative.value
        case .positive:      return PregnancyTestEnum.positive.value
        @unknown default:    return PregnancyTestEnum.inconclusive.value
        }
    }
}

extension HKCategoryValueProgesteroneTestResult {
    var progesteroneTestValue: String {
        switch self {
        case .indeterminate: return ProgesteroneTestEnum.inconclusive.value
        case .negative:      return ProgesteroneTestEnum.negative.value
        case .positive:      return ProgesteroneTestEnum.positive.value
        @unknown default:    return ProgesteroneTestEnum.inconclusive.value
        }
    }
}

extension HKCategoryValueContraceptive {
    var contraceptiveValue: String {
        switch self {
        case .unspecified:      return ContraceptiveEnum.unknown.value
        case .implant:          return ContraceptiveEnum.implant.value
        case .injection:        return ContraceptiveEnum.injection.value
        case .intravaginalRing: return ContraceptiveEnum.intravaginalRing.value
        case .iud:              return ContraceptiveEnum.iud.value
        case .oral:             return ContraceptiveEnum.oral.value
        case .patch:            return ContraceptiveEnum.patch.value
        @unknown default:       return ContraceptiveEnum.unknown.value
        }
    }
}

