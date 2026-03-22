// ─── Reproductive Enums ───────────────────────────────────────────────────────
//
// Ordinal values are shared across iOS (HealthKit) and Android (Health Connect)
// so that DataLog.value is platform-agnostic.
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
