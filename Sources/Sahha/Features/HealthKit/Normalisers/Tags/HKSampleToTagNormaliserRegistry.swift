import HealthKit

final class HKSampleToTagNormaliserRegistry: HKSampleToTagNormaliserProtocol {

    private static let menstrualFlow = HKMenstrualFlowToTagNormaliser()
    private static let cervicalMucus = HKCervicalMucusToTagNormaliser()
    private static let ovulationTest = HKOvulationTestToTagNormaliser()
    private static let sexualActivity = HKSexualActivityToTagNormaliser()
    private static let pregnancyTest = HKPregnancyTestToTagNormaliser()
    private static let progesteroneTest = HKProgesteroneTestToTagNormaliser()
    private static let contraceptive = HKContraceptiveToTagNormaliser()
    private static let reproductiveFlag = HKReproductiveFlagToTagNormaliser()
    private static let symptom = HKSymptomToTagNormaliser()

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
            HKCategoryTypeIdentifier.abdominalCramps.rawValue: symptom,
            HKCategoryTypeIdentifier.acne.rawValue: symptom,
            HKCategoryTypeIdentifier.appetiteChanges.rawValue: symptom,
            HKCategoryTypeIdentifier.bloating.rawValue: symptom,
            HKCategoryTypeIdentifier.breastPain.rawValue: symptom,
            HKCategoryTypeIdentifier.chestTightnessOrPain.rawValue: symptom,
            HKCategoryTypeIdentifier.chills.rawValue: symptom,
            HKCategoryTypeIdentifier.constipation.rawValue: symptom,
            HKCategoryTypeIdentifier.coughing.rawValue: symptom,
            HKCategoryTypeIdentifier.diarrhea.rawValue: symptom,
            HKCategoryTypeIdentifier.dizziness.rawValue: symptom,
            HKCategoryTypeIdentifier.fainting.rawValue: symptom,
            HKCategoryTypeIdentifier.fatigue.rawValue: symptom,
            HKCategoryTypeIdentifier.fever.rawValue: symptom,
            HKCategoryTypeIdentifier.generalizedBodyAche.rawValue: symptom,
            HKCategoryTypeIdentifier.headache.rawValue: symptom,
            HKCategoryTypeIdentifier.heartburn.rawValue: symptom,
            HKCategoryTypeIdentifier.hotFlashes.rawValue: symptom,
            HKCategoryTypeIdentifier.lossOfSmell.rawValue: symptom,
            HKCategoryTypeIdentifier.lossOfTaste.rawValue: symptom,
            HKCategoryTypeIdentifier.lowerBackPain.rawValue: symptom,
            HKCategoryTypeIdentifier.moodChanges.rawValue: symptom,
            HKCategoryTypeIdentifier.nausea.rawValue: symptom,
            HKCategoryTypeIdentifier.pelvicPain.rawValue: symptom,
            HKCategoryTypeIdentifier.rapidPoundingOrFlutteringHeartbeat.rawValue: symptom,
            HKCategoryTypeIdentifier.runnyNose.rawValue: symptom,
            HKCategoryTypeIdentifier.shortnessOfBreath.rawValue: symptom,
            HKCategoryTypeIdentifier.sinusCongestion.rawValue: symptom,
            HKCategoryTypeIdentifier.skippedHeartbeat.rawValue: symptom,
            HKCategoryTypeIdentifier.sleepChanges.rawValue: symptom,
            HKCategoryTypeIdentifier.soreThroat.rawValue: symptom,
            HKCategoryTypeIdentifier.vomiting.rawValue: symptom,
            HKCategoryTypeIdentifier.wheezing.rawValue: symptom,
        ]

        // iOS 14.0+
        if #available(iOS 14.0, *) {
            map[HKCategoryTypeIdentifier.bladderIncontinence.rawValue] = symptom
            map[HKCategoryTypeIdentifier.drySkin.rawValue] = symptom
            map[HKCategoryTypeIdentifier.hairLoss.rawValue] = symptom
            map[HKCategoryTypeIdentifier.memoryLapse.rawValue] = symptom
            map[HKCategoryTypeIdentifier.nightSweats.rawValue] = symptom
            map[HKCategoryTypeIdentifier.vaginalDryness.rawValue] = symptom
        }

        // iOS 14.3+
        if #available(iOS 14.3, *) {
            map[HKCategoryTypeIdentifier.contraceptive.rawValue] = contraceptive
            map[HKCategoryTypeIdentifier.pregnancy.rawValue] = reproductiveFlag
            map[HKCategoryTypeIdentifier.lactation.rawValue] = reproductiveFlag
        }

        // iOS 15.0+
        if #available(iOS 15.0, *) {
            map[HKCategoryTypeIdentifier.pregnancyTestResult.rawValue] = pregnancyTest
            map[HKCategoryTypeIdentifier.progesteroneTestResult.rawValue] = progesteroneTest
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

    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] {
        let key = sample.sampleType.identifier
        return Self.normalisers[key]?.normalise(sample, profileId: profileId) ?? []
    }
}
