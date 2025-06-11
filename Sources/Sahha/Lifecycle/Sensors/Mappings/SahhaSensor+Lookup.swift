import Foundation

extension SahhaSensor {
    init?(dataType: String) {
        if let exact = SahhaSensor(rawValue: dataType) {
            self = exact
            return
        }
        
        if dataType.starts(with: "exercise_session_") {
            self = .exercise
            return
        }
        
        if dataType.starts(with: "sleep_stage_") {
            self = .sleep
            return
        }
        
        return nil
    }
}
