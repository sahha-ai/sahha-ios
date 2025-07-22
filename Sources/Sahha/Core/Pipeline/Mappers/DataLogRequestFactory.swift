import Foundation

protocol DataLogRequestFactory: Sendable {
  func makeRequest(from log: DataLog) async -> DataLogRequest
}
