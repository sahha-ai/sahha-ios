import HealthKit

/// Normalises sleep analysis samples into a `sleep_session` parent log per
/// derived session, with each stage sample as a child referencing the
/// session's id via `parentId`.
///
/// Sessions are derived per source by clustering the batch
/// (see `SleepSessionGrouper`), so sleep samples must be normalised together
/// as a batch — a night split across query pages produces a separate partial
/// session per page.
final class HKSleepAnalysisToDataLogNormaliser: HKSampleToDataLogNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [DataLog] {
        normalise([sample], profileId: profileId)
    }

    func normalise(_ samples: [HKSample], profileId: String?) -> [DataLog] {
        let sleepSamples = samples.compactMap { sample -> HKCategorySample? in
            guard let sample = sample as? HKCategorySample,
                let sensor = sample.categoryType.sahhaSensor,
                sensor == .sleep
            else { return nil }
            return sample
        }
        guard !sleepSamples.isEmpty else { return [] }

        let samplesBySource = Dictionary(grouping: sleepSamples) { $0.sourceId }

        return samplesBySource.values.flatMap { sourceSamples in
            SleepSessionGrouper.groupIntoSessions(sourceSamples, start: \.startDate, end: \.endDate)
                .flatMap { normaliseSession($0, profileId: profileId) }
        }
    }

    private func normaliseSession(_ session: [HKCategorySample], profileId: String?) -> [DataLog] {
        guard let first = session.first,
            let sensor = first.categoryType.sahhaSensor
        else { return [] }

        let sessionStart = session.map(\.startDate).min() ?? first.startDate
        let sessionEnd = session.map(\.endDate).max() ?? first.endDate

        let parent = DataLog(
            profileId: profileId,
            logType: sensor.dataLogType,
            dataType: "sleep_session",
            value: minutes(from: sessionStart, to: sessionEnd),
            unit: sensor.unitString,
            source: first.sourceId,
            recordingMethod: first.recordingMethod,
            deviceType: first.deviceType,
            startDate: sessionStart,
            endDate: sessionEnd
        )

        let stageLogs = session.map { sample -> DataLog in
            let sleepStage = HKCategoryValueSleepAnalysis(rawValue: sample.value)?.name ?? "unknown"

            return DataLog(
                profileId: profileId,
                parentId: parent.id,
                logType: sensor.dataLogType,
                dataType: "sleep_stage_\(sleepStage)",
                value: minutes(from: sample.startDate, to: sample.endDate),
                unit: sensor.unitString,
                source: sample.sourceId,
                recordingMethod: sample.recordingMethod,
                deviceType: sample.deviceType,
                startDate: sample.startDate,
                endDate: sample.endDate
            )
        }

        return [parent] + stageLogs
    }

    private func minutes(from start: Date, to end: Date) -> Double {
        let duration = Calendar.current.dateComponents([.minute], from: start, to: end).minute ?? 0
        return Double(duration).rounded(toPlaces: 4)
    }
}
