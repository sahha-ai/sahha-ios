import Testing
import Foundation
import HealthKit

@testable import Sahha

// Coverage for lenient sensor-store decoding — the core fix for the 1.3.9
// sensor-store poisoning. 1.3.9 renamed 43 sensor raw values without migrating
// the persisted "sensors" key, so stores written by 1.3.7-era SDKs failed strict
// decoding on every read: getSensors() threw forever, every caller swallowed the
// error, and collection went permanently silent after one backfill. The store
// now decodes raw strings, maps them through the rename table, self-heals
// storage, and latches an anomaly report for the authenticated bring-up to post.

@Suite("SensorStore lenient decoding")
struct SensorStoreLenientDecodingTests {

    private let key = StorageKeys.UserDefaults.sensors.rawValue

    /// A byte-level 1.3.7-era blob: JSON array of legacy raw values, exactly as
    /// `JSONEncoder().encode(Set<SahhaSensor>)` persisted it at 1.3.7.
    private func blob(_ rawValues: [String]) -> Data {
        try! JSONEncoder().encode(rawValues)
    }

    private func reads(of storage: InMemoryStorage) -> Int {
        storage.readKeys.filter { $0 == key }.count
    }

    private func writes(of storage: InMemoryStorage) -> Int {
        storage.writtenKeys.filter { $0 == key }.count
    }

    private func storedRawValues(in storage: InMemoryStorage) throws -> Set<String> {
        let data = try #require(storage.get(forKey: key) as? Data)
        return Set(try JSONDecoder().decode([String].self, from: data))
    }

    // MARK: - Incident repro and healing

    @Test("A 1.3.7-era blob returns the mapped set, rewrites storage canonically, and latches one anomaly")
    func incidentReproHealsPoisonedBlob() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar", "dietary_fat_total", "cervical_mucus_quality", "sleep"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        let sensors = try await store.getSensors()

        #expect(sensors == [.sugar_intake, .fat_intake, .cervical_mucus, .sleep])
        #expect(writes(of: storage) == 2)  // seed + one canonical rewrite
        #expect(try storedRawValues(in: storage) == ["sugar_intake", "fat_intake", "cervical_mucus", "sleep"])
        #expect(await store.drainPendingAnomaly() == .healedValues(
            renamed: ["cervical_mucus_quality", "dietary_fat_total", "dietary_sugar"],
            droppedUnknown: []
        ))
        #expect(await store.drainPendingAnomaly() == nil)
    }

    @Test("A second store construction over healed storage is byte-identical with zero further anomalies")
    func healingIsIdempotent() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar", "sleep"]), forKey: key)
        _ = try await SensorStore(storage: storage, key: key).getSensors()
        let healedBytes = try #require(storage.get(forKey: key) as? Data)
        let writesAfterHeal = writes(of: storage)

        let secondStore = SensorStore(storage: storage, key: key)
        let sensors = try await secondStore.getSensors()

        #expect(sensors == [.sugar_intake, .sleep])
        #expect(storage.get(forKey: key) as? Data == healedBytes)
        #expect(writes(of: storage) == writesAfterHeal)
        #expect(await secondStore.drainPendingAnomaly() == nil)
    }

    @Test("Healthy contents pass through with no anomaly and no rewrite")
    func healthyPassThrough() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["sleep", "steps"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        let sensors = try await store.getSensors()

        #expect(sensors == [.sleep, .steps])
        #expect(writes(of: storage) == 1)  // the seed only
        #expect(await store.drainPendingAnomaly() == nil)
    }

    @Test("An absent key reads as empty with no anomaly and no rewrite")
    func absentKey() async throws {
        let storage = InMemoryStorage()
        let store = SensorStore(storage: storage, key: key)

        #expect(try await store.getSensors() == [])
        #expect(writes(of: storage) == 0)
        #expect(await store.drainPendingAnomaly() == nil)
    }

    // MARK: - Guards

    @Test("A foreign non-Data value is left untouched and reported by type name only")
    func foreignValueLeftUntouched() async throws {
        let storage = InMemoryStorage()
        storage.set("not the SDK's data", forKey: key)
        let store = SensorStore(storage: storage, key: key)

        #expect(try await store.getSensors() == [])
        #expect(writes(of: storage) == 1)  // the seed only — never rewritten or deleted
        #expect(storage.get(forKey: key) as? String == "not the SDK's data")

        let anomaly = try #require(await store.drainPendingAnomaly())
        guard case let .foreignValue(typeName) = anomaly else {
            Issue.record("Expected .foreignValue, got \(anomaly)")
            return
        }
        #expect(typeName.contains("String"))
        // The value itself must never appear in the report.
        #expect(!String(describing: anomaly).contains("not the SDK's data"))
    }

    @Test("Undecodable Data is left untouched")
    func undecodableDataLeftUntouched() async throws {
        let storage = InMemoryStorage()
        let garbage = Data("definitely not json".utf8)
        storage.set(garbage, forKey: key)
        let store = SensorStore(storage: storage, key: key)

        #expect(try await store.getSensors() == [])
        #expect(writes(of: storage) == 1)
        #expect(storage.get(forKey: key) as? Data == garbage)
        #expect(await store.drainPendingAnomaly() == .undecodableData(byteCount: garbage.count))
    }

    @Test("Mixed old and new contents union-dedup safely")
    func mixedOldNewUnionDedup() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar", "sugar_intake", "sleep"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        let sensors = try await store.getSensors()

        #expect(sensors == [.sugar_intake, .sleep])
        #expect(try storedRawValues(in: storage) == ["sugar_intake", "sleep"])
        #expect(await store.drainPendingAnomaly() == .healedValues(
            renamed: ["dietary_sugar"],
            droppedUnknown: []
        ))
    }

    @Test("All-unknown contents return empty, latch an anomaly, and leave storage unchanged")
    func allUnknownGuard() async throws {
        let storage = InMemoryStorage()
        let futureBlob = blob(["quantum_flux", "neural_lace"])
        storage.set(futureBlob, forKey: key)
        let store = SensorStore(storage: storage, key: key)

        #expect(try await store.getSensors() == [])
        #expect(writes(of: storage) == 1)  // no rewrite: likely a downgrade from a future SDK
        #expect(storage.get(forKey: key) as? Data == futureBlob)
        #expect(await store.drainPendingAnomaly() == .allUnknownValues(["neural_lace", "quantum_flux"]))
    }

    // MARK: - hasSensor and concurrency

    @Test("hasSensor is consistent over a poisoned blob with no prior getSensors call")
    func hasSensorOverPoisonedBlob() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        #expect(await store.hasSensor(.sugar_intake))
        #expect(!(await store.hasSensor(.steps)))
        #expect(await store.drainPendingAnomaly() != nil)
    }

    @Test("Twenty concurrent first reads produce one rewrite and one latched anomaly")
    func concurrentFirstReads() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar", "sleep"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        let results = await withTaskGroup(of: Set<SahhaSensor>.self) { group in
            for _ in 0..<20 {
                group.addTask { (try? await store.getSensors()) ?? [] }
            }
            var collected: [Set<SahhaSensor>] = []
            for await result in group {
                collected.append(result)
            }
            return collected
        }

        #expect(results.count == 20)
        #expect(results.allSatisfy { $0 == [.sugar_intake, .sleep] })
        #expect(writes(of: storage) == 2)  // seed + exactly one rewrite
        #expect(await store.drainPendingAnomaly() != nil)
        #expect(await store.drainPendingAnomaly() == nil)
    }

    // MARK: - Latch, cache, dispose

    @Test("Reads never consume the latched anomaly; drain returns it exactly once")
    func drainSemantics() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["dietary_sugar"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        _ = try await store.getSensors()
        _ = try await store.getSensors()
        _ = await store.hasSensor(.sugar_intake)

        #expect(await store.drainPendingAnomaly() != nil)
        #expect(await store.drainPendingAnomaly() == nil)
        _ = try await store.getSensors()
        #expect(await store.drainPendingAnomaly() == nil)
    }

    @Test("After the first resolve, reads never re-hit storage")
    func cacheAvoidsRepeatReads() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["sleep"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)

        _ = try await store.getSensors()
        _ = try await store.getSensors()
        _ = await store.hasSensor(.sleep)
        _ = await store.hasSensor(.steps)

        #expect(reads(of: storage) == 1)
    }

    @Test("An absent key is cached too: repeat reads never re-hit storage")
    func cacheCoversAbsentKey() async throws {
        let storage = InMemoryStorage()
        let store = SensorStore(storage: storage, key: key)

        _ = try await store.getSensors()
        _ = try await store.getSensors()
        _ = await store.hasSensor(.sleep)

        #expect(reads(of: storage) == 1)
    }

    @Test("Dispose clears the key and the cache")
    func disposeRoundTrip() async throws {
        let storage = InMemoryStorage()
        storage.set(blob(["sleep"]), forKey: key)
        let store = SensorStore(storage: storage, key: key)
        #expect(try await store.getSensors() == [.sleep])

        await store.dispose()

        #expect(!storage.allKeys().contains(key))
        #expect(try await store.getSensors() == [])
        #expect(!(await store.hasSensor(.sleep)))
    }
}

// MARK: - End-to-end self-heal through the launch-time resume path

/// The production symptom, inverted: a poisoned 1.3.7-era blob plus a
/// launch-time `resumeSensors()` must yield the mapped set to the resume path
/// and arm both coordinators — no `enableSensors` call, no re-auth, no
/// app-side change.
@Suite("SensorStore end-to-end self-heal")
struct SensorStoreEndToEndSelfHealTests {

    @Test("A poisoned blob plus a launch-time resume arms both coordinators with the mapped set")
    func resumeArmsBothCoordinators() async throws {
        let key = StorageKeys.UserDefaults.sensors.rawValue
        let storage = InMemoryStorage()
        storage.set(
            try JSONEncoder().encode(["dietary_sugar", "dietary_fat_total", "cervical_mucus_quality", "sleep"]),
            forKey: key
        )
        let sensorStore = SensorStore(storage: storage, key: key)
        let dataLogSpy = SpyDataLogCoordinator()
        let tagSpy = SpyTagCoordinator()
        let manager = HealthKitManager(
            permissions: HealthKitPermissionsService(healthStore: RecordingHealthStore(), requestTimeout: 5),
            sensorStore: sensorStore,
            dataLogCoordinator: dataLogSpy,
            tagCoordinator: tagSpy,
            statCoordinator: StubStatCoordinator(),
            sampleCoordinator: StubSampleCoordinator(),
            demographicService: StubDemographicService(),
            activitySummaryUploader: StubActivitySummaryUploader(),
            logger: NoopErrorLogger()
        )

        await manager.resumeSensors()

        // Reproductive sensors go to the tag coordinator, the rest to data logs.
        #expect(await tagSpy.startedSensors == [.cervical_mucus])
        #expect(await dataLogSpy.startedSensors == [.sugar_intake, .fat_intake, .sleep])
        // Storage healed as a side effect of the resume's read.
        let healed = try #require(storage.get(forKey: key) as? Data)
        #expect(Set(try JSONDecoder().decode([String].self, from: healed))
            == ["sugar_intake", "fat_intake", "cervical_mucus", "sleep"])
    }
}

// MARK: - Harness stubs (self-contained for this suite)

private actor SpyDataLogCoordinator: HealthKitDataLogCoordinatorProtocol {
    private(set) var startedSensors: Set<SahhaSensor> = []

    func startDataLogCollection(for sensors: Set<SahhaSensor>) async throws {
        startedSensors.formUnion(sensors)
    }
    func stopDataLogCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private actor SpyTagCoordinator: HealthKitTagCoordinatorProtocol {
    private(set) var startedSensors: Set<SahhaSensor> = []

    func startTagCollection(for sensors: Set<SahhaSensor>) async throws {
        startedSensors.formUnion(sensors)
    }
    func stopTagCollection(for sensors: Set<SahhaSensor>) async throws {}
    func querySensors(_ sensors: Set<SahhaSensor>) async -> [SensorQueryResult] { [] }
}

private struct StubStatCoordinator: HealthKitSahhaStatCoordinatorProtocol {
    func getStats(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaStat] { [] }
}

private struct StubSampleCoordinator: HealthKitSahhaSampleCoordinatorProtocol {
    func getSamples(for sensor: SahhaSensor, startDateTime: Date, endDateTime: Date) async throws -> [SahhaSample] { [] }
}

private struct StubDemographicService: HealthKitDemographicServiceProtocol {
    func fetchGender() async throws -> HKBiologicalSex { .notSet }
    func fetchDateOfBirth() async throws -> Date? { nil }
}

private struct StubActivitySummaryUploader: HealthKitActivitySummaryUploaderProtocol {
    func postInsights() async {}
}
