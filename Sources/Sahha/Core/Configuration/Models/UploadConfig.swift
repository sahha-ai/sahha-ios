/// Configuration for upload behavior across the SDK
struct UploadConfig {
    /// Maximum chunk size in kilobytes
    let maxChunkKB: Int
    
    /// Maximum number of logs per chunk
    let maxLogsPerChunk: Int
    
    /// Maximum concurrent uploads
    let maxConcurrentUploads: Int
    
    /// Maximum retry attempts for failed uploads
    let maxRetries: Int
    
    /// Default configuration
    static let `default` = UploadConfig(
        maxChunkKB: 150,
        maxLogsPerChunk: 100,
        maxConcurrentUploads: 3,
        maxRetries: 10
    )
}

