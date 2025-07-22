import Foundation

enum LifecycleQueues {
    static let `default`: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.sahha.lifecycleEventQueue"
        q.qualityOfService = .utility
        q.maxConcurrentOperationCount = 1
        return q
    }()

    static let background: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.sahha.lifecycleBackgroundQueue"
        q.qualityOfService = .background
        q.maxConcurrentOperationCount = 1
        return q
    }()
}
