import Foundation

final class TagRequestMapper: TagRequestMapperProtocol {
    private let deviceId: String

    init(deviceId: String) {
        self.deviceId = deviceId
    }

    func map(_ tag: Tag) -> TagRequest {
        buildRequestBody(for: tag)
    }

    func map(_ tags: [Tag]) -> [TagRequest] {
        tags.map(buildRequestBody)
    }

    private func buildRequestBody(for tag: Tag) -> TagRequest {
        TagRequest(
            id: tag.id,
            type: tag.type.rawValue,
            startDateTime: tag.startDateTime.isoDateTime,
            endDateTime: tag.endDateTime?.isoDateTime,
            name: tag.name,
            category: tag.category,
            value: tag.value,
            source: tag.source,
            additionalProperties: tag.additionalProperties,
            deviceId: deviceId
        )
    }
}
