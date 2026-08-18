import Testing
import Foundation
import HealthKit

@testable import Sahha

// Coverage for anchor continuity across the 1.3.9 sensor renames (PRD #76 D7).
// 1.3.9 renamed 43 sensor raw values, and anchors persist under rawValue-derived
// keys — so a recovered install would find no anchor under the new name,
// re-backfill 30 days, and re-upload it all. Log IDs derive from local-wall-clock
// timestamp formatting, so re-normalising the same samples across a timezone/DST
// change yields genuinely different IDs; avoided re-uploads are a correctness
// matter, not an optimisation. The store now aliases reads through the shared
// rename table's reverse direction; saves stay canonical and old keys are never
// deleted (the canonical write is not prompt — coordinators skip saving when a
// query returns no samples — and deletion would make downgrades re-backfill).
//
// Storage keys are written as full literals throughout: they are the on-disk
// compatibility surface on real devices, and must never change silently.

@Suite("Anchor read-time alias")
struct AnchorReadTimeAliasTests {

    private func archivedAnchor(_ value: Int) throws -> Data {
        try NSKeyedArchiver.archivedData(
            withRootObject: HKQueryAnchor(fromValue: value),
            requiringSecureCoding: true
        )
    }

    // MARK: - Load order

    @Test("Canonical-key hit returns the anchor for a sensor with no rename-table entry")
    func canonicalHitWithoutRenameEntry() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(7), forKey: "hkAnchor.steps")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .steps) == HKQueryAnchor(fromValue: 7))
    }

    @Test("Canonical-key hit returns the anchor for a renamed sensor")
    func canonicalHitForRenamedSensor() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(7), forKey: "hkAnchor.energy_intake")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 7))
    }

    @Test("Old-name alias hit returns the anchor written by a pre-rename SDK")
    func oldNameAliasHit() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(7), forKey: "hkAnchor.energy_consumed")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 7))
    }

    @Test("Legacy-prefixed old-name alias hit returns the anchor")
    func legacyPrefixedOldNameAliasHit() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(7), forKey: "sahha_hkAnchor.energy_consumed")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 7))
    }

    @Test("The canonical key wins when all four key forms exist")
    func canonicalWinsWhenAllFourKeysExist() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(1), forKey: "hkAnchor.energy_intake")
        storage.set(try archivedAnchor(2), forKey: "sahha_hkAnchor.energy_intake")
        storage.set(try archivedAnchor(3), forKey: "hkAnchor.energy_consumed")
        storage.set(try archivedAnchor(4), forKey: "sahha_hkAnchor.energy_consumed")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 1))
    }

    @Test("Both canonical-name forms win over both old-name forms")
    func legacyPrefixedCanonicalWinsOverOldNameKeys() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(2), forKey: "sahha_hkAnchor.energy_intake")
        storage.set(try archivedAnchor(3), forKey: "hkAnchor.energy_consumed")
        storage.set(try archivedAnchor(4), forKey: "sahha_hkAnchor.energy_consumed")
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 2))
    }

    @Test("A fresh-install miss returns nil and writes nothing")
    func freshInstallMissReturnsNil() async throws {
        let storage = InMemoryStorage()
        let store = HealthKitAnchorStore(storage: storage)

        #expect(try await store.loadAnchor(for: .energy_intake) == nil)
        #expect(storage.writtenKeys.isEmpty)
    }

    // MARK: - Saves

    @Test("A save is canonical and leaves the old-name keys in place")
    func saveLeavesOldNameKeysInPlace() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(3), forKey: "hkAnchor.energy_consumed")
        storage.set(try archivedAnchor(4), forKey: "sahha_hkAnchor.energy_consumed")
        let store = HealthKitAnchorStore(storage: storage)

        try await store.saveAnchor(HKQueryAnchor(fromValue: 9), for: .energy_intake)

        let keys = Set(storage.allKeys())
        #expect(keys == ["hkAnchor.energy_intake", "hkAnchor.energy_consumed", "sahha_hkAnchor.energy_consumed"])
        // The fresh canonical anchor now shadows the stale old-name ones.
        #expect(try await store.loadAnchor(for: .energy_intake) == HKQueryAnchor(fromValue: 9))
    }

    // MARK: - Dispose

    @Test("Anchor-store dispose wipes the canonical and legacy-prefixed key families, nothing else")
    func anchorDisposeWipesBothKeyFamilies() async throws {
        let storage = InMemoryStorage()
        storage.set(try archivedAnchor(1), forKey: "hkAnchor.steps")
        storage.set(try archivedAnchor(2), forKey: "sahha_hkAnchor.energy_consumed")
        storage.set(Date(timeIntervalSince1970: 1_000_000), forKey: "hkAnchorDate.activity_summary")
        storage.set(Date(timeIntervalSince1970: 2_000_000), forKey: "date_hkAnchorDate.activity_summary")
        storage.set(Data(), forKey: "sensors")
        let store = HealthKitAnchorStore(storage: storage)

        await store.dispose()

        #expect(Set(storage.allKeys()) == [
            "hkAnchorDate.activity_summary",
            "date_hkAnchorDate.activity_summary",
            "sensors",
        ])
        // The resurrection vector is closed: nothing left for the alias to find.
        #expect(try await store.loadAnchor(for: .energy_intake) == nil)
    }

    @Test("Anchor-date-store dispose wipes the canonical and legacy-prefixed key families, nothing else")
    func anchorDateDisposeWipesBothKeyFamilies() async throws {
        let storage = InMemoryStorage()
        storage.set(Date(timeIntervalSince1970: 1_000_000), forKey: "hkAnchorDate.activity_summary")
        storage.set(Date(timeIntervalSince1970: 2_000_000), forKey: "date_hkAnchorDate.activity_summary")
        storage.set(try archivedAnchor(1), forKey: "hkAnchor.steps")
        storage.set(try archivedAnchor(2), forKey: "sahha_hkAnchor.steps")
        let store = HealthKitAnchorDateStore(storage: storage)

        await store.dispose()

        #expect(Set(storage.allKeys()) == ["hkAnchor.steps", "sahha_hkAnchor.steps"])
        #expect(await store.loadAnchorDate(for: .activity_summary) == nil)
    }

    // MARK: - Anchor-date store stays alias-free

    @Test("The anchor-date store still honours its legacy-prefixed key")
    func anchorDateLegacyPrefixedKeyStillRead() async {
        let storage = InMemoryStorage()
        let date = Date(timeIntervalSince1970: 1_000_000)
        storage.set(date, forKey: "date_hkAnchorDate.activity_summary")
        let store = HealthKitAnchorDateStore(storage: storage)

        #expect(await store.loadAnchorDate(for: .activity_summary) == date)
    }

    @Test("The anchor-date store does not alias old sensor names")
    func anchorDateDoesNotAliasOldNames() async {
        let storage = InMemoryStorage()
        storage.set(Date(timeIntervalSince1970: 1_000_000), forKey: "hkAnchorDate.energy_consumed")
        let store = HealthKitAnchorDateStore(storage: storage)

        #expect(await store.loadAnchorDate(for: .energy_intake) == nil)
    }
}
