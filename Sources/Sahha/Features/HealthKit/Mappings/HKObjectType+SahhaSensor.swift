import HealthKit

extension HKObjectType {
    var sahhaSensor: SahhaSensor? {
        Self.sahhaSensorMap[self.identifier]
    }

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

