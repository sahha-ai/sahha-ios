import Foundation
import HealthKit

@testable import Sahha

// These live here, in a file that does not import Testing, because `Tag` is
// ambiguous wherever both modules are visible (Testing exports a Tag type of its
// own) and the Sahha module name is shadowed by the `Sahha` class, which rules
// out qualifying it at the use site.

struct NullTagNormaliser: HKSampleToTagNormaliserProtocol {
    func normalise(_ sample: HKSample, profileId: String?) -> [Tag] { [] }
}

actor NullTagPipeline: TagPipelineProtocol {
    func ingest(_ tag: Tag) async {}
    func ingest(_ tags: [Tag]) async {}
}
