//
//  HealthKitError.swift
//  Sahha
//
//  Created by Connor Cain on 17/07/2025.
//

import Foundation

enum HealthKitError: LocalizedError {
    case healthKitUnavailable
    case invalidSensorType(SahhaSensor)
    case permissionDenied(SahhaSensor)
    case noStatsFound(SahhaSensor)
    
    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            "HealthKit is unavailable on this device."
        case .invalidSensorType(let sensor):
            "Invalid sensor type: \(sensor.rawValue)"
        case .permissionDenied(let sensor):
            "Permission denied for \(sensor.rawValue)."
        case .noStatsFound(let sensor):
            "No stats found for \(sensor.rawValue)."
        }
    }
}
