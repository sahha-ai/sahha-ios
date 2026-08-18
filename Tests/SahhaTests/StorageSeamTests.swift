import Testing
import Foundation
@testable import Sahha

/// Coverage for the injectable storage seam (PRD #76, D2a): typed reads must route
/// through the protocol's primitives so injected doubles intercept them, and the
/// production `UserDefaultsStorage` must keep `UserDefaults`' native semantics.
@Suite("Storage seam")
struct StorageSeamTests {

    private struct Payload: Codable, Equatable {
        let value: Int
    }

    // MARK: - Injected doubles intercept typed access

    @Test("data(forKey:) reads the injected double, not UserDefaults.standard")
    func dataReadsRouteThroughDouble() {
        let key = "seam.data.\(UUID().uuidString)"
        // Pre-seam, the extension read UserDefaults.standard directly — plant a decoy
        // there to prove the double now wins.
        UserDefaults.standard.set(Data("decoy".utf8), forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let injected = InMemoryStorage()
        injected.set(Data("double".utf8), forKey: key)

        let storage: UserDefaultsStorageProtocol = injected
        #expect(storage.data(forKey: key) == Data("double".utf8))
        #expect(injected.readKeys.contains(key))
    }

    @Test("object/setObject round-trip through the double without touching UserDefaults.standard")
    func codableRoundTripStaysInDouble() throws {
        let key = "seam.object.\(UUID().uuidString)"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let injected = InMemoryStorage()
        let storage: UserDefaultsStorageProtocol = injected

        try storage.setObject(Payload(value: 7), forKey: key)
        // Pre-seam, setObject wrote UserDefaults.standard directly.
        #expect(UserDefaults.standard.data(forKey: key) == nil)

        let decoded: Payload? = try storage.object(forKey: key)
        #expect(decoded == Payload(value: 7))
        #expect(injected.readKeys.contains(key))
        #expect(injected.writtenKeys.contains(key))
    }

    @Test("Typed accessors on a double fall back to primitive-backed defaults")
    func typedDefaultsRouteThroughPrimitives() {
        let injected = InMemoryStorage()
        injected.set("text", forKey: "s")
        injected.set(true, forKey: "b")
        injected.set(7, forKey: "i")
        injected.set(1.5, forKey: "d")
        let stamp = Date(timeIntervalSince1970: 1_000_000)
        injected.set(stamp, forKey: "when")

        let storage: UserDefaultsStorageProtocol = injected
        #expect(storage.string(forKey: "s") == "text")
        #expect(storage.bool(forKey: "b") == true)
        #expect(storage.integer(forKey: "i") == 7)
        #expect(storage.double(forKey: "d") == 1.5)
        #expect(storage.date(forKey: "when") == stamp)
        // Absent keys report the same defaults UserDefaults does.
        #expect(storage.string(forKey: "missing") == nil)
        #expect(storage.bool(forKey: "missing") == false)
        #expect(storage.integer(forKey: "missing") == 0)
        #expect(storage.data(forKey: "missing") == nil)
        #expect(storage.array(forKey: "missing") == nil)
        #expect(storage.dictionary(forKey: "missing") == nil)
    }

    // MARK: - Production semantics pinned (live call sites: string, date, data)

    @Test("UserDefaultsStorage.string keeps native NSNumber → String coercion")
    func stringCoercionPinned() {
        let key = "seam.coerce.\(UUID().uuidString)"
        let storage = UserDefaultsStorage()
        defer { storage.removeObject(forKey: key) }

        storage.set(123, forKey: key)

        // The device-id provider reads through string(forKey:) — a plain
        // `get as? String` would return nil here and regenerate device ids.
        #expect(storage.string(forKey: key) == "123")

        storage.set("abc", forKey: key)
        #expect(storage.string(forKey: key) == "abc")
        #expect(storage.string(forKey: "seam.absent.\(UUID().uuidString)") == nil)
    }

    @Test("UserDefaultsStorage.date and .data round-trip, with absent-key nils")
    func dateAndDataPinned() {
        let dateKey = "seam.date.\(UUID().uuidString)"
        let dataKey = "seam.bytes.\(UUID().uuidString)"
        let storage = UserDefaultsStorage()
        defer {
            storage.removeObject(forKey: dateKey)
            storage.removeObject(forKey: dataKey)
        }

        let stamp = Date(timeIntervalSince1970: 1_000_000)
        storage.set(stamp, forKey: dateKey)
        #expect(storage.date(forKey: dateKey) == stamp)
        #expect(storage.data(forKey: dateKey) == nil)   // non-Data value stays nil, as before

        let bytes = Data([0x01, 0x02])
        storage.set(bytes, forKey: dataKey)
        #expect(storage.data(forKey: dataKey) == bytes)
        #expect(storage.date(forKey: "seam.absent.\(UUID().uuidString)") == nil)
        #expect(storage.data(forKey: "seam.absent.\(UUID().uuidString)") == nil)
    }

    @Test("Primitive get uses object(forKey:) semantics, including KVC-special keys")
    func primitiveGetIsNotKVC() {
        // NSUserDefaults' value(forKey:) diverts "@"-prefixed keys into NSObject KVC,
        // which raises for undefined keys; object(forKey:) treats them as plain keys.
        let key = "@seam.\(UUID().uuidString)"
        let storage = UserDefaultsStorage()
        defer { storage.removeObject(forKey: key) }

        storage.set("stored", forKey: key)
        #expect(storage.get(forKey: key) as? String == "stored")
    }
}
