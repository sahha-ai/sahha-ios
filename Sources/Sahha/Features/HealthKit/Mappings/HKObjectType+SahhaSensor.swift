import HealthKit

extension HKObjectType {
    /// Returns the corresponding SahhaSensor, if known.
    var sahhaSensor: SahhaSensor? {
        // Build static map only once
        return Self.sahhaSensorMap[self.identifier]
    }

    /// Static dictionary for reverse mapping
    private static let sahhaSensorMap: [String: SahhaSensor] = {
        var map = [String: SahhaSensor]()
        for sensor in SahhaSensor.allCases {
            if let type = sensor.hkObjectType {
                map[type.identifier] = sensor
            }
        }
        return map
    }()
}
