import Foundation

extension Interceptor {
    var id: String { String(describing: Self.self) }
    var priority: Int { 0 }
}
