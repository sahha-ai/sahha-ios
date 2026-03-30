import HealthKit

final class HKSampleToTagNormaliserRegistry: HKSampleToTagNormaliserProtocol {

    private static let menstrualFlow = HKMenstrualFlowToTagNormaliser()
    private static let cervicalMucus = HKCervicalMucusToTagNormaliser()
    private static let ovulationTest = HKOvulationTestToTagNormaliser()
    private static let sexualActivity = HKSexualActivityToTagNormaliser()
    private static let pregnancyTest = HKPregnancyTestToTagNormaliser()
    private static let reproductiveFlag = HKReproductiveFlagToTagNormaliser()
    private static let reproductiveSymptom = HKReproductiveSymptomToTagNormaliser()

    private static let normalisers: [String: HKSampleToTagNormaliserProtocol] = {
        var map: [String: HKSampleToTagNormaliserProtocol] = [
            // Menstrual Cycle
            HKCategoryTypeIdentifier.menstrualFlow.rawValue: menstrualFlow,
            HKCategoryTypeIdentifier.intermenstrualBleeding.rawValue: reproductiveFlag,

            // Fertility
            HKCategoryTypeIdentifier.ovulationTestResult.rawValue: ovulationTest,
            HKCategoryTypeIdentifier.cervicalMucusQuality.rawValue: cervicalMucus,

            // Sexual Activity
            HKCategoryTypeIdentifier.sexualActivity.rawValue: sexualActivity,

            // Symptoms
            HKCategoryTypeIdentifier.abdominalCramps.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.acne.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.appetiteChanges.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.bloating.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.breastPain.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.chills.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.constipation.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.diarrhea.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.dizziness.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.fatigue.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.headache.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.hotFlashes.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.lowerBackPain.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.moodChanges.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.nausea.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.pelvicPain.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.rapidPoundingOrFlutteringHeartbeat.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.sinusCongestion.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.skippedHeartbeat.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.sleepChanges.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.soreThroat.rawValue: reproductiveSymptom,
            HKCategoryTypeIdentifier.vomiting.rawValue: reproductiveSymptom,
        ]

        // iOS 14.0+
        if #available(iOS 14.0, *) {
            map[HKCategoryTypeIdentifier.bladderIncontinence.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.drySkin.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.hairLoss.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.memoryLapse.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.nightSweats.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.runnyNose.rawValue] = reproductiveSymptom
            map[HKCategoryTypeIdentifier.vaginalDryness.rawValue] = reproductiveSymptom
        }

        // iOS 14.3+
        if #available(iOS 14.3, *) {
            map[HKCategoryTypeIdentifier.contraceptive.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.pregnancy.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.lactation.rawValue] = reproductiveFlag
        }

        // iOS 15.0+
        if #available(iOS 15.0, *) {
            map[HKCategoryTypeIdentifier.pregnancyTestResult.rawValue] = pregnancyTest
            map[HKCategoryTypeIdentifier.progesteroneTestResult.rawValue] = pregnancyTest
        }

        // iOS 16.0+
        if #available(iOS 16.0, *) {
            map[HKCategoryTypeIdentifier.infrequentMenstrualCycles.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.irregularMenstrualCycles.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.persistentIntermenstrualBleeding.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.prolongedMenstrualPeriods.rawValue] = reproductiveFlag
        }

        return map
    }()

    func normalise(_ sample: HKSample) -> [Tag] {
        let key = sample.sampleType.identifier
        return Self.normalisers[key]?.normalise(sample) ?? []
    }
}
