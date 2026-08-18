import Testing

@testable import Sahha

/// Completeness fixture for the 1.3.7 → 1.3.9 sensor rename table. The 43
/// legacy strings are embedded here as literals, independent of the production
/// table, so an accidental edit to either side fails loudly instead of
/// silently shrinking the healing surface.
@Suite("SahhaSensor rename table")
struct SahhaSensorRenameTableTests {

    /// Legacy raw value → expected current raw value, transcribed from the
    /// 1.3.7 tag (joined on HealthKit identifiers). Deliberately NOT derived
    /// from the production table.
    private static let expectedRenames: [String: String] = [
        "dietary_biotin": "biotin_intake",
        "dietary_caffeine": "caffeine_intake",
        "dietary_calcium": "calcium_intake",
        "dietary_carbohydrates": "carbohydrate_intake",
        "dietary_chloride": "chloride_intake",
        "dietary_cholesterol": "cholesterol_intake",
        "dietary_chromium": "chromium_intake",
        "dietary_copper": "copper_intake",
        "dietary_fat_monounsaturated": "fat_monounsaturated_intake",
        "dietary_fat_polyunsaturated": "fat_polyunsaturated_intake",
        "dietary_fat_saturated": "fat_saturated_intake",
        "dietary_fat_total": "fat_intake",
        "dietary_fiber": "fiber_intake",
        "dietary_folate": "folate_intake",
        "dietary_iodine": "iodine_intake",
        "dietary_iron": "iron_intake",
        "dietary_magnesium": "magnesium_intake",
        "dietary_manganese": "manganese_intake",
        "dietary_molybdenum": "molybdenum_intake",
        "dietary_niacin": "niacin_intake",
        "dietary_pantothenic_acid": "pantothenic_acid_intake",
        "dietary_phosphorus": "phosphorus_intake",
        "dietary_potassium": "potassium_intake",
        "dietary_protein": "protein_intake",
        "dietary_riboflavin": "riboflavin_intake",
        "dietary_selenium": "selenium_intake",
        "dietary_sodium": "sodium_intake",
        "dietary_sugar": "sugar_intake",
        "dietary_thiamin": "thiamin_intake",
        "dietary_vitamin_a": "vitamin_a_intake",
        "dietary_vitamin_b12": "vitamin_b12_intake",
        "dietary_vitamin_b6": "vitamin_b6_intake",
        "dietary_vitamin_c": "vitamin_c_intake",
        "dietary_vitamin_d": "vitamin_d_intake",
        "dietary_vitamin_e": "vitamin_e_intake",
        "dietary_vitamin_k": "vitamin_k_intake",
        "dietary_water": "water_intake",
        "dietary_zinc": "zinc_intake",
        "energy_consumed": "energy_intake",
        "cervical_mucus_quality": "cervical_mucus",
        "ovulation_test_result": "ovulation_test",
        "pregnancy_test_result": "pregnancy_test",
        "progesterone_test_result": "progesterone_test",
    ]

    @Test("The table covers exactly the 43 renamed sensors")
    func tableIsComplete() {
        #expect(Self.expectedRenames.count == 43)
        #expect(SahhaSensor.legacyRenames.count == 43)
        #expect(Set(SahhaSensor.legacyRenames.map(\.legacy)) == Set(Self.expectedRenames.keys))
    }

    @Test("Every legacy value resolves to its expected current sensor")
    func fullResolution() throws {
        for (legacy, current) in Self.expectedRenames {
            let resolved = try #require(
                SahhaSensor.fromPersistedRawValue(legacy),
                "\(legacy) did not resolve"
            )
            #expect(resolved.rawValue == current, "\(legacy) resolved to \(resolved.rawValue), expected \(current)")
        }
    }

    @Test("The mapping is injective: 43 distinct current sensors")
    func injectivity() {
        #expect(Set(SahhaSensor.legacyRenames.map(\.current)).count == 43)
    }

    @Test("No legacy value collides with a current raw value")
    func disjointness() {
        for legacy in Self.expectedRenames.keys {
            #expect(SahhaSensor(rawValue: legacy) == nil, "\(legacy) is still a live raw value")
        }
    }

    @Test("Both derived dictionaries carry all 43 entries")
    func derivedDictionaryIntegrity() {
        #expect(SahhaSensor.legacyToCurrentSensor.count == 43)
        #expect(SahhaSensor.currentToLegacyRawValue.count == 43)
    }

    @Test("Old and new values round-trip through the derived dictionaries")
    func roundTrip() throws {
        for (legacy, current) in Self.expectedRenames {
            let sensor = try #require(SahhaSensor.legacyToCurrentSensor[legacy])
            #expect(sensor.rawValue == current)
            #expect(SahhaSensor.currentToLegacyRawValue[sensor.rawValue] == legacy)
        }
    }

    @Test("Every current raw value resolves to itself without the table")
    func currentValuesResolveDirectly() {
        for sensor in SahhaSensor.allCases {
            #expect(SahhaSensor.fromPersistedRawValue(sensor.rawValue) == sensor)
        }
    }
}
