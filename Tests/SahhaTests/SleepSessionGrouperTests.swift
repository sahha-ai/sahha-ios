import Testing
import Foundation
@testable import Sahha

private struct Interval {
    let start: Date
    let end: Date

    init(startMinute: Double, endMinute: Double) {
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        self.start = base.addingTimeInterval(startMinute * 60)
        self.end = base.addingTimeInterval(endMinute * 60)
    }
}

private func group(_ intervals: [Interval], gap: TimeInterval = SleepSessionGrouper.sessionGap) -> [[Interval]] {
    SleepSessionGrouper.groupIntoSessions(intervals, start: \.start, end: \.end, gap: gap)
}

@Test("SleepSessionGrouper: Empty input produces no sessions")
func testGrouperEmptyInput() {
    #expect(group([]).isEmpty)
}

@Test("SleepSessionGrouper: Single element produces one session")
func testGrouperSingleElement() {
    let sessions = group([Interval(startMinute: 0, endMinute: 90)])
    #expect(sessions.count == 1)
    #expect(sessions[0].count == 1)
}

@Test("SleepSessionGrouper: Contiguous elements share one session")
func testGrouperContiguousElements() {
    let sessions = group([
        Interval(startMinute: 0, endMinute: 90),
        Interval(startMinute: 90, endMinute: 200),
        Interval(startMinute: 200, endMinute: 450)
    ])
    #expect(sessions.count == 1)
    #expect(sessions[0].count == 3)
}

@Test("SleepSessionGrouper: Gap over threshold splits sessions")
func testGrouperSplitsOnGap() {
    let sessions = group([
        Interval(startMinute: 0, endMinute: 450),
        Interval(startMinute: 800, endMinute: 830)
    ])
    #expect(sessions.count == 2)
}

@Test("SleepSessionGrouper: Gap exactly at threshold stays in one session")
func testGrouperGapAtThreshold() {
    let sessions = group([
        Interval(startMinute: 0, endMinute: 60),
        Interval(startMinute: 120, endMinute: 180)
    ])
    #expect(sessions.count == 1)
}

@Test("SleepSessionGrouper: Unsorted input is sorted before grouping")
func testGrouperSortsInput() {
    let sessions = group([
        Interval(startMinute: 800, endMinute: 830),
        Interval(startMinute: 0, endMinute: 450),
        Interval(startMinute: 100, endMinute: 200)
    ])
    #expect(sessions.count == 2)
    #expect(sessions[0].count == 2)
    #expect(sessions[1].count == 1)
}

@Test("SleepSessionGrouper: Contained element extends nothing and splits nothing")
func testGrouperContainedElement() {
    // An in_bed span enclosing stage samples, followed by a sample within
    // the gap of the enclosing END (not the contained element's end).
    let sessions = group([
        Interval(startMinute: 0, endMinute: 480),
        Interval(startMinute: 10, endMinute: 30),
        Interval(startMinute: 500, endMinute: 530)
    ])
    #expect(sessions.count == 1)
}

@Test("SleepSessionGrouper: Overlapping elements share one session")
func testGrouperOverlappingElements() {
    let sessions = group([
        Interval(startMinute: 0, endMinute: 100),
        Interval(startMinute: 50, endMinute: 150)
    ])
    #expect(sessions.count == 1)
}
