import Testing
import Foundation
@testable import Sahha

// MARK: - DIContainer concurrency regression

private final class ResolvableProbe: @unchecked Sendable {
    let id = UUID()
}

private actor ConstructionCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

@Test("DIContainer: concurrent resolution of one type yields a single shared instance")
func testContainerConcurrentResolutionReturnsSameInstance() async throws {
    let container = DIContainer()
    let counter = ConstructionCounter()

    await container.register(ResolvableProbe.self) { _ in
        // Suspend inside the factory so concurrent resolves overlap in the await
        // window — the interleaving that previously produced duplicate singletons.
        await counter.increment()
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
        return ResolvableProbe()
    }

    let instances = try await withThrowingTaskGroup(of: ResolvableProbe.self) { group in
        for _ in 0..<32 {
            group.addTask { try await container.resolve(ResolvableProbe.self) }
        }
        var collected: [ResolvableProbe] = []
        for try await instance in group {
            collected.append(instance)
        }
        return collected
    }

    // All concurrent resolutions return the identical object…
    let first = try #require(instances.first)
    #expect(instances.count == 32)
    #expect(instances.allSatisfy { $0 === first })

    // …and the factory ran exactly once.
    let constructionsAfterGroup = await counter.count
    #expect(constructionsAfterGroup == 1)

    // A later resolve hits the instance cache — same object, no new construction.
    let later = try await container.resolve(ResolvableProbe.self)
    #expect(later === first)
    let finalConstructions = await counter.count
    #expect(finalConstructions == 1)
}
