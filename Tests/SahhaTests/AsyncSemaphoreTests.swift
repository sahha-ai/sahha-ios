import Foundation
import Testing

@testable import Sahha

// Coverage for AsyncSemaphore's cancellable wait, which the anchored-query slots rely
// on: a sensor stopped while it is queued for a slot must leave the queue without
// taking a permit, or the slot pool would shrink with every stop.

/// Tracks how many holders are inside a guarded section at once.
private actor OccupancyTracker {
    private(set) var current = 0
    private(set) var peak = 0

    func enter() {
        current += 1
        peak = max(peak, current)
    }

    func leave() { current -= 1 }
}

/// Records the order in which waiters were granted a permit.
private actor GrantLog {
    private(set) var order: [String] = []

    func record(_ name: String) { order.append(name) }
}

private func waitUntil(timeout: Double = 5, _ condition: @Sendable () async -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return await condition()
}

@Suite("AsyncSemaphore cancellable wait")
struct AsyncSemaphoreCancellableWaitTests {

    @Test("Never grants more permits at once than it holds")
    func neverExceedsCapacity() async throws {
        let semaphore = AsyncSemaphore(value: 3)
        let tracker = OccupancyTracker()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<12 {
                group.addTask {
                    try await semaphore.cancellableWait()
                    await tracker.enter()
                    try? await Task.sleep(nanoseconds: 20_000_000)
                    await tracker.leave()
                    await semaphore.signal()
                }
            }
            try await group.waitForAll()
        }

        #expect(await tracker.peak == 3)
        #expect(await semaphore.load == AsyncSemaphore.Load(inUse: 0, waiting: 0, capacity: 3))
    }

    @Test("A waiter cancelled in the queue throws, leaves the queue, and takes no permit")
    func cancelledWaiterLeavesQueue() async throws {
        let semaphore = AsyncSemaphore(value: 1)
        try await semaphore.cancellableWait()  // the holder

        let waiter = Task { try await semaphore.cancellableWait() }
        #expect(await waitUntil { await semaphore.load.waiting == 1 })

        waiter.cancel()
        await #expect(throws: CancellationError.self) { try await waiter.value }
        #expect(await semaphore.load == AsyncSemaphore.Load(inUse: 1, waiting: 0, capacity: 1))

        // The holder's permit returns to the pool rather than to the departed waiter.
        await semaphore.signal()
        #expect(await semaphore.load.inUse == 0)
        try await semaphore.cancellableWait()
        #expect(await semaphore.load.inUse == 1)
    }

    @Test("A task that is already cancelled throws even when a permit is free")
    func alreadyCancelledTaskThrows() async {
        let semaphore = AsyncSemaphore(value: 1)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await semaphore.cancellableWait()
        }

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await semaphore.load.inUse == 0)
    }

    @Test("Permits go to waiters in arrival order, whichever kind of wait they used")
    func arrivalOrderAcrossWaitKinds() async throws {
        let semaphore = AsyncSemaphore(value: 1)
        let grants = GrantLog()
        try await semaphore.cancellableWait()  // the holder

        let first = Task {
            try await semaphore.cancellableWait()
            await grants.record("first")
            await semaphore.signal()
        }
        #expect(await waitUntil { await semaphore.load.waiting == 1 })
        let second = Task {
            await semaphore.wait()
            await grants.record("second")
            await semaphore.signal()
        }
        #expect(await waitUntil { await semaphore.load.waiting == 2 })

        await semaphore.signal()
        try await first.value
        await second.value

        #expect(await grants.order == ["first", "second"])
        #expect(await semaphore.load.inUse == 0)
    }
}
