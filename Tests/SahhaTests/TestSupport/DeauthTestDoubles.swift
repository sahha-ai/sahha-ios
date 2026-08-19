import Foundation
@testable import Sahha

// These live here, in a file that does not import Testing, because `Tag` is
// ambiguous wherever both modules are visible (Testing exports a Tag type of
// its own) — same arrangement as TagTestDoubles.

/// A reusable open/wait latch: waiters park until `open()`, arrivals are
/// observable so tests can pin "the flow reached this point".
actor DeauthGate {
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var arrivals = 0

    func open() {
        opened = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }

    func waitUntilOpen() async {
        arrivals += 1
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

/// Parks the container reset inside its dispose pass, holding deauthentication
/// mid-teardown so a racing API call can be observed deterministically.
actor GateTagPipeline: TagPipelineProtocol, Disposable {
    private let gate: DeauthGate
    init(gate: DeauthGate) { self.gate = gate }
    func ingest(_ tag: Tag) async {}
    func ingest(_ tags: [Tag]) async {}
    func dispose() async {
        await gate.waitUntilOpen()
    }
}
