//
//  HKHeartRateSensorLocation+StringValue.swift
//  Sahha
//
//  Created by Connor Cain on 21/07/2025.
//

import HealthKit

extension HKHeartRateSensorLocation {
    var stringValue: String {
        switch self {
        case .chest: return "chest"
        case .earLobe: return "ear_lobe"
        case .finger: return "finger"
        case .foot: return "foot"
        case .hand: return "hand"
        case .wrist: return "wrist"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
