/// Rename mapping for sensor raw values persisted by SDKs before 1.3.9, which
/// renamed 39 nutrition and 4 reproductive sensors without migrating persisted
/// state. `SensorStore` resolves persisted values through
/// `fromPersistedRawValue`, so a set written by a 1.3.7-era SDK maps to today's
/// cases instead of poisoning every read.
extension SahhaSensor {
    /// The (legacy, current) raw-value pairs, declared once; both lookup
    /// directions derive from this table. Recovered from the 1.3.7 tag by
    /// joining the two enum generations on their HealthKit identifiers.
    static let legacyRenames: [(legacy: String, current: String)] = [
        // Nutrition (39)
        ("dietary_biotin", "biotin_intake"),
        ("dietary_caffeine", "caffeine_intake"),
        ("dietary_calcium", "calcium_intake"),
        ("dietary_carbohydrates", "carbohydrate_intake"),
        ("dietary_chloride", "chloride_intake"),
        ("dietary_cholesterol", "cholesterol_intake"),
        ("dietary_chromium", "chromium_intake"),
        ("dietary_copper", "copper_intake"),
        ("dietary_fat_monounsaturated", "fat_monounsaturated_intake"),
        ("dietary_fat_polyunsaturated", "fat_polyunsaturated_intake"),
        ("dietary_fat_saturated", "fat_saturated_intake"),
        ("dietary_fat_total", "fat_intake"),
        ("dietary_fiber", "fiber_intake"),
        ("dietary_folate", "folate_intake"),
        ("dietary_iodine", "iodine_intake"),
        ("dietary_iron", "iron_intake"),
        ("dietary_magnesium", "magnesium_intake"),
        ("dietary_manganese", "manganese_intake"),
        ("dietary_molybdenum", "molybdenum_intake"),
        ("dietary_niacin", "niacin_intake"),
        ("dietary_pantothenic_acid", "pantothenic_acid_intake"),
        ("dietary_phosphorus", "phosphorus_intake"),
        ("dietary_potassium", "potassium_intake"),
        ("dietary_protein", "protein_intake"),
        ("dietary_riboflavin", "riboflavin_intake"),
        ("dietary_selenium", "selenium_intake"),
        ("dietary_sodium", "sodium_intake"),
        ("dietary_sugar", "sugar_intake"),
        ("dietary_thiamin", "thiamin_intake"),
        ("dietary_vitamin_a", "vitamin_a_intake"),
        ("dietary_vitamin_b12", "vitamin_b12_intake"),
        ("dietary_vitamin_b6", "vitamin_b6_intake"),
        ("dietary_vitamin_c", "vitamin_c_intake"),
        ("dietary_vitamin_d", "vitamin_d_intake"),
        ("dietary_vitamin_e", "vitamin_e_intake"),
        ("dietary_vitamin_k", "vitamin_k_intake"),
        ("dietary_water", "water_intake"),
        ("dietary_zinc", "zinc_intake"),
        ("energy_consumed", "energy_intake"),
        // Reproductive (4)
        ("cervical_mucus_quality", "cervical_mucus"),
        ("ovulation_test_result", "ovulation_test"),
        ("pregnancy_test_result", "pregnancy_test"),
        ("progesterone_test_result", "progesterone_test"),
    ]

    /// Legacy raw value → current sensor. Derived non-trappingly: duplicate or
    /// unresolvable table entries surface in the completeness fixture instead of
    /// crashing the SDK at type initialisation.
    static let legacyToCurrentSensor: [String: SahhaSensor] = Dictionary(
        legacyRenames.compactMap { pair in
            SahhaSensor(rawValue: pair.current).map { (pair.legacy, $0) }
        },
        uniquingKeysWith: { first, _ in first }
    )

    /// Current raw value → legacy raw value: backs the anchor store's
    /// read-time alias (a renamed sensor's anchor is found under its old-name
    /// key) and the round-trip fixture.
    static let currentToLegacyRawValue: [String: String] = Dictionary(
        legacyRenames.map { ($0.current, $0.legacy) },
        uniquingKeysWith: { first, _ in first }
    )

    /// Resolves a raw value read from persisted state: the current names are
    /// tried first, so healthy stores never touch the rename table. Unknown
    /// values resolve to nil — they can never make a read throw.
    static func fromPersistedRawValue(_ rawValue: String) -> SahhaSensor? {
        SahhaSensor(rawValue: rawValue) ?? legacyToCurrentSensor[rawValue]
    }
}
