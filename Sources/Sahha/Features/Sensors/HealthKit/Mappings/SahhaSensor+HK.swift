import HealthKit

extension SahhaSensor {
    private var meta: HKSensorMapping.Metadata? { HKSensorMapping.forward[self] }

    var hkObjectType: HKObjectType? {
        meta?.hkObjectType
    }

    var hkUnit: HKUnit? {
        meta?.hkUnit
    }

    var hkStatsOptions: HKStatisticsOptions {
        meta?.statsOptions ?? .cumulativeSum
    }

    var hkPermissions: Set<HKObjectType> {
        guard let meta = meta else { return [] }
        return Set([ meta.hkObjectType ]).union(meta.additionalPermissions)
    }
}
