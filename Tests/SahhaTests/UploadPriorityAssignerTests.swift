import Foundation
import Testing

@testable import Sahha

// The uploader sends higher priorities first, and the dead-letter queue retries them
// first. Steps go first of all; HealthKit data and device lock events next; the app
// lifecycle device logs (one at every launch, background or foreground) after them.
@Suite("Upload priority by log")
struct UploadPriorityAssignerTests {
    private let assigner = DefaultUploadPriorityAssigner()

    @Test("Steps are critical")
    func stepsAreCritical() {
        #expect(assigner.assignPriority(to: log(.activity, "steps")) == .critical)
    }

    @Test("Device lock and unlock events are high, though they are device logs")
    func deviceLockIsHigh() {
        // As DeviceLogLifecycleListener writes them: value 1 for locked, 0 for unlocked.
        for value in [1.0, 0.0] {
            let lockLog = log(.device, SahhaSensor.device_lock.rawValue, value: value)
            #expect(assigner.assignPriority(to: lockLog) == .high)
        }
    }

    @Test("HealthKit data is high", arguments: [
        (DataLogType.heart, "heart_rate"),
        (.sleep, "sleep_stage_deep"),
        (.energy, "active_energy_burned"),
        (.body, "weight"),
    ])
    func healthKitDataIsHigh(logType: DataLogType, dataType: String) {
        #expect(assigner.assignPriority(to: log(logType, dataType)) == .high)
    }

    @Test("App lifecycle device logs stay normal", arguments: LifecycleEvent.allCases.filter {
        $0 != .app_locked && $0 != .app_unlocked
    })
    func appLifecycleLogsAreNormal(event: LifecycleEvent) {
        // As DeviceLogLifecycleListener writes them: the event's name is the data type.
        #expect(assigner.assignPriority(to: log(.device, event.rawValue)) == .normal)
    }

    private func log(_ logType: DataLogType, _ dataType: String, value: Double = 1) -> DataLog {
        DataLog(
            logType: logType,
            dataType: dataType,
            value: value,
            unit: "",
            source: "ai.sahha.tests",
            recordingMethod: .automatic,
            deviceType: "iPhone",
            startDate: Date(),
            endDate: Date()
        )
    }
}
