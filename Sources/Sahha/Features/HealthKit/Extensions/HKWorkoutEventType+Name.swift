import HealthKit

extension HKWorkoutEventType {
    var name: String {
        switch self {
        case .pause: return "pause"
        case .resume: return "resume"
        case .lap: return "lap"
        case .marker: return "marker"
        case .motionPaused: return "motion_paused"
        case .motionResumed: return "motion_resumed"
        case .segment: return "segment"
        case .pauseOrResumeRequest: return "pause_or_resume_request"
        @unknown default: return "unknown"
        }
    }
}

