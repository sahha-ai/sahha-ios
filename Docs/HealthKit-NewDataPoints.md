# New HealthKit Data Points Implementation

**Branch:** `feature/extending-data-collection-to-nutritional-and-reproductive-data-points-with-healthkit`  
**Date:** January 28, 2026

---

## Summary

| Category | New Data Points | Type |
|----------|-----------------|------|
| **Nutrition** | 37 | HKQuantityType |
| **Reproductive Health** | 43 | HKCategoryType |
| **TOTAL** | **80** | Mixed |

---

## 🍎 NUTRITION DATA POINTS (37 new)

All nutrition types use `HKQuantityType` and can leverage the existing `FallbackHKSampleToDataLogNormaliser`.

### Macronutrients (6)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 1 | `dietary_protein` | `.dietaryProtein` | gram | `g` |
| 2 | `dietary_fat_total` | `.dietaryFatTotal` | gram | `g` |
| 3 | `dietary_fat_saturated` | `.dietaryFatSaturated` | gram | `g` |
| 4 | `dietary_fat_monounsaturated` | `.dietaryFatMonounsaturated` | gram | `g` |
| 5 | `dietary_fat_polyunsaturated` | `.dietaryFatPolyunsaturated` | gram | `g` |
| 6 | `dietary_cholesterol` | `.dietaryCholesterol` | milligram | `mg` |

### Carbohydrates (3)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 7 | `dietary_carbohydrates` | `.dietaryCarbohydrates` | gram | `g` |
| 8 | `dietary_sugar` | `.dietarySugar` | gram | `g` |
| 9 | `dietary_fiber` | `.dietaryFiber` | gram | `g` |

### Vitamins - Fat Soluble (4)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 10 | `dietary_vitamin_a` | `.dietaryVitaminA` | microgram | `mcg` |
| 11 | `dietary_vitamin_d` | `.dietaryVitaminD` | microgram | `mcg` |
| 12 | `dietary_vitamin_e` | `.dietaryVitaminE` | milligram | `mg` |
| 13 | `dietary_vitamin_k` | `.dietaryVitaminK` | microgram | `mcg` |

### Vitamins - Water Soluble (9)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 14 | `dietary_vitamin_c` | `.dietaryVitaminC` | milligram | `mg` |
| 15 | `dietary_vitamin_b6` | `.dietaryVitaminB6` | milligram | `mg` |
| 16 | `dietary_vitamin_b12` | `.dietaryVitaminB12` | microgram | `mcg` |
| 17 | `dietary_thiamin` | `.dietaryThiamin` | milligram | `mg` |
| 18 | `dietary_riboflavin` | `.dietaryRiboflavin` | milligram | `mg` |
| 19 | `dietary_niacin` | `.dietaryNiacin` | milligram | `mg` |
| 20 | `dietary_pantothenic_acid` | `.dietaryPantothenicAcid` | milligram | `mg` |
| 21 | `dietary_folate` | `.dietaryFolate` | microgram | `mcg` |
| 22 | `dietary_biotin` | `.dietaryBiotin` | microgram | `mcg` |

### Minerals - Major (7)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 23 | `dietary_calcium` | `.dietaryCalcium` | milligram | `mg` |
| 24 | `dietary_iron` | `.dietaryIron` | milligram | `mg` |
| 25 | `dietary_magnesium` | `.dietaryMagnesium` | milligram | `mg` |
| 26 | `dietary_phosphorus` | `.dietaryPhosphorus` | milligram | `mg` |
| 27 | `dietary_potassium` | `.dietaryPotassium` | milligram | `mg` |
| 28 | `dietary_sodium` | `.dietarySodium` | milligram | `mg` |
| 29 | `dietary_zinc` | `.dietaryZinc` | milligram | `mg` |

### Minerals - Trace (7)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 30 | `dietary_chloride` | `.dietaryChloride` | milligram | `mg` |
| 31 | `dietary_copper` | `.dietaryCopper` | milligram | `mg` |
| 32 | `dietary_manganese` | `.dietaryManganese` | milligram | `mg` |
| 33 | `dietary_chromium` | `.dietaryChromium` | microgram | `mcg` |
| 34 | `dietary_molybdenum` | `.dietaryMolybdenum` | microgram | `mcg` |
| 35 | `dietary_selenium` | `.dietarySelenium` | microgram | `mcg` |
| 36 | `dietary_iodine` | `.dietaryIodine` | microgram | `mcg` |

### Other Nutrition (2)

| # | SahhaSensor | HKQuantityTypeIdentifier | Unit | unitString |
|---|-------------|-------------------------|------|------------|
| 37 | `dietary_caffeine` | `.dietaryCaffeine` | milligram | `mg` |
| 38 | `dietary_water` | `.dietaryWater` | liter | `L` |

---

## 🩺 REPRODUCTIVE HEALTH DATA POINTS (43 new)

All reproductive types use `HKCategoryType`. Requires a new normaliser for `HKCategorySample`.

### Menstrual Cycle Core (6)

| # | SahhaSensor | HKCategoryTypeIdentifier | iOS | Values |
|---|-------------|-------------------------|-----|--------|
| 1 | `menstrual_flow` | `.menstrualFlow` | 9.0+ | unspecified, light, medium, heavy, none |
| 2 | `intermenstrual_bleeding` | `.intermenstrualBleeding` | 9.0+ | present/notPresent |
| 3 | `infrequent_menstrual_cycles` | `.infrequentMenstrualCycles` | 14.3+ | event |
| 4 | `irregular_menstrual_cycles` | `.irregularMenstrualCycles` | 14.3+ | event |
| 5 | `persistent_intermenstrual_bleeding` | `.persistentIntermenstrualBleeding` | 14.3+ | event |
| 6 | `prolonged_menstrual_periods` | `.prolongedMenstrualPeriods` | 14.3+ | event |

### Fertility Tracking (2)

| # | SahhaSensor | HKCategoryTypeIdentifier | iOS | Values |
|---|-------------|-------------------------|-----|--------|
| 7 | `ovulation_test_result` | `.ovulationTestResult` | 9.0+ | negative, luteinizingHormoneSurge, estrogenSurge, indeterminate |
| 8 | `cervical_mucus_quality` | `.cervicalMucusQuality` | 9.0+ | dry, sticky, creamy, watery, eggWhite |

### Sexual Activity (2)

| # | SahhaSensor | HKCategoryTypeIdentifier | iOS | Metadata |
|---|-------------|-------------------------|-----|----------|
| 9 | `sexual_activity` | `.sexualActivity` | 9.0+ | HKMetadataKeySexualActivityProtectionUsed |
| 10 | `contraceptive` | `.contraceptive` | 14.3+ | unspecified, implant, injection, iud, etc. |

### Pregnancy & Lactation (4)

| # | SahhaSensor | HKCategoryTypeIdentifier | iOS | Values |
|---|-------------|-------------------------|-----|--------|
| 11 | `pregnancy` | `.pregnancy` | 14.3+ | event |
| 12 | `pregnancy_test_result` | `.pregnancyTestResult` | 15.0+ | negative, positive, indeterminate |
| 13 | `progesterone_test_result` | `.progesteroneTestResult` | 15.0+ | negative, positive, indeterminate |
| 14 | `lactation` | `.lactation` | 14.3+ | event |

### Symptoms - Cycle Related (29)

| # | SahhaSensor | HKCategoryTypeIdentifier | iOS | Values |
|---|-------------|-------------------------|-----|--------|
| 15 | `abdominal_cramps` | `.abdominalCramps` | 13.6+ | notPresent, mild, moderate, severe |
| 16 | `acne` | `.acne` | 13.6+ | notPresent, mild, moderate, severe |
| 17 | `appetite_changes` | `.appetiteChanges` | 13.6+ | noChange, decreased, increased |
| 18 | `bladder_incontinence` | `.bladderIncontinence` | 14.0+ | notPresent, mild, moderate, severe |
| 19 | `bloating` | `.bloating` | 13.6+ | notPresent, mild, moderate, severe |
| 20 | `breast_pain` | `.breastPain` | 13.6+ | notPresent, mild, moderate, severe |
| 21 | `chills` | `.chills` | 13.6+ | notPresent, mild, moderate, severe |
| 22 | `constipation` | `.constipation` | 13.6+ | notPresent, mild, moderate, severe |
| 23 | `diarrhea` | `.diarrhea` | 13.6+ | notPresent, mild, moderate, severe |
| 24 | `dizziness` | `.dizziness` | 13.6+ | notPresent, mild, moderate, severe |
| 25 | `dry_skin` | `.drySkin` | 14.0+ | notPresent, mild, moderate, severe |
| 26 | `fatigue` | `.fatigue` | 13.6+ | notPresent, mild, moderate, severe |
| 27 | `hair_loss` | `.hairLoss` | 14.0+ | notPresent, mild, moderate, severe |
| 28 | `headache` | `.headache` | 13.6+ | notPresent, mild, moderate, severe |
| 29 | `hot_flashes` | `.hotFlashes` | 13.6+ | notPresent, mild, moderate, severe |
| 30 | `lower_back_pain` | `.lowerBackPain` | 13.6+ | notPresent, mild, moderate, severe |
| 31 | `memory_lapse` | `.memoryLapse` | 14.0+ | notPresent, mild, moderate, severe |
| 32 | `mood_changes` | `.moodChanges` | 13.6+ | notPresent, mild, moderate, severe |
| 33 | `nausea` | `.nausea` | 13.6+ | notPresent, mild, moderate, severe |
| 34 | `night_sweats` | `.nightSweats` | 14.0+ | notPresent, mild, moderate, severe |
| 35 | `pelvic_pain` | `.pelvicPain` | 13.6+ | notPresent, mild, moderate, severe |
| 36 | `rapid_pounding_or_fluttering_heartbeat` | `.rapidPoundingOrFlutteringHeartbeat` | 13.6+ | notPresent, mild, moderate, severe |
| 37 | `runny_nose` | `.runnyNose` | 13.6+ | notPresent, mild, moderate, severe |
| 38 | `sinus_congestion` | `.sinusCongestion` | 13.6+ | notPresent, mild, moderate, severe |
| 39 | `skipped_heartbeat` | `.skippedHeartbeat` | 13.6+ | notPresent, mild, moderate, severe |
| 40 | `sleep_changes` | `.sleepChanges` | 13.6+ | notPresent, mild, moderate, severe |
| 41 | `sore_throat` | `.soreThroat` | 13.6+ | notPresent, mild, moderate, severe |
| 42 | `vaginal_dryness` | `.vaginalDryness` | 14.0+ | notPresent, mild, moderate, severe |
| 43 | `vomiting` | `.vomiting` | 13.6+ | notPresent, mild, moderate, severe |

---

## Implementation Checklist

### Phase 1: Infrastructure
- [ ] Add `reproductive` to `DataLogType` enum
- [ ] Create `HKCategoryToDataLogNormaliser.swift`
- [ ] Register normaliser in `HKSampleToDataLogNormaliserRegistry`

### Phase 2: Nutrition Data Points (37)
- [ ] Add 37 cases to `SahhaSensor` enum
- [ ] Add HK mappings to `SahhaSensor+HKObjectType.swift`
- [ ] Add unit mappings to `SahhaSensor+HKUnit.swift`
- [ ] Add data log type mappings to `SahhaSensor+DataLogType.swift`
- [ ] Add unit strings to `SahhaSensor+UnitString.swift`

### Phase 3: Reproductive Health Data Points (43)
- [ ] Add 43 cases to `SahhaSensor` enum
- [ ] Add HK mappings to `SahhaSensor+HKObjectType.swift`
- [ ] Add data log type mappings to `SahhaSensor+DataLogType.swift`
- [ ] Add unit strings to `SahhaSensor+UnitString.swift` (empty for categories)

### Phase 4: Testing & Documentation
- [ ] Build and verify no compile errors
- [ ] Update demo app to test new sensors
- [ ] Update SDK documentation

---

## Code Snippets for Implementation

### 1. DataLogType.swift - Add reproductive

```swift
enum DataLogType: Int, Codable {
    case demographic
    case sleep
    case activity
    case device
    case heart
    case blood
    case oxygen
    case energy
    case temperature
    case body
    case exercise
    case nutrition
    case reproductive  // NEW

    var stringValue: String { String(describing: self) }
}
```

### 2. New Category Normaliser

```swift
import HealthKit

final class HKCategoryToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample) -> [DataLog] {
        guard let sample = sample as? HKCategorySample,
              let sensor = sample.categoryType.sahhaSensor
        else { return [] }
        
        return [
            DataLog(
                logType: sensor.dataLogType,
                dataType: sensor.rawValue,
                value: Double(sample.value),
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        ]
    }
}
```
