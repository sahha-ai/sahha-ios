import Foundation

protocol DataLogRequestMapping: Sendable {
    /// Maps a single DataLog to a DataLogRequest, asynchronously.
    func map(_ log: DataLog) async throws -> DataLogRequest
    
    /// Maps an array of DataLog to DataLogRequest, asynchronously.
    func map(_ logs: [DataLog]) async throws -> [DataLogRequest]
}
