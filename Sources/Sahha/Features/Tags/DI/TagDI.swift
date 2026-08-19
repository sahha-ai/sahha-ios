enum TagDI {
    static func registerDependencies(container: DIContainer) async {
        await container.register(TagServiceProtocol.self) { container in
            TagService(
                apiClient: try await container.resolve(APIClientProtocol.self)
            )
        }
        await container.register(TagRequestMapperProtocol.self) { container in
            TagRequestMapper(
                deviceId: try await container.resolve(DeviceIdProviderProtocol.self).deviceId()
            )
        }

        // Unified upload infrastructure for Tags
        let tagCircuitBreaker = CircuitBreaker()
        let tagNetworkMonitor = NetworkMonitor()

        await container.register(TagUploaderProtocol.self) { container in
            let service = try await container.resolve(TagServiceProtocol.self)
            let mapper = try await container.resolve(TagRequestMapperProtocol.self)

            return UnifiedUploader<Tag, TagRequest>(
                uploadService: { requests in
                    try await service.postTags(requests)
                },
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                circuitBreaker: tagCircuitBreaker,
                networkMonitor: tagNetworkMonitor,
                persistentQueue: UnifiedDeadLetterQueue<TagRequest>(
                    baseDirectory: StorageDirectories.tags,
                    maxStoredBatches: 500,
                    logLabel: "Tag Persistent Queue"
                ),
                streamingProcessor: StreamingChunkProcessor<Tag, TagRequest>(
                    mapItem: { tag in mapper.map(tag) },
                    assignPriority: { _ in .normal },
                    config: .default
                ),
                sentStore: SentItemStore(
                    storage: try await container.resolve(UserDefaultsStorageProtocol.self),
                    storageKey: StorageKeys.UserDefaults.sentTagIds.rawValue,
                    logLabel: "SentTagStore"
                ),
                logLabel: "TagUploader"
            )
        }

        await container.register(TagPipelineProtocol.self) { container in
            TagPipeline(
                uploader: try await container.resolve(TagUploaderProtocol.self)
            )
        }

        await container.register(TagRetryLifecycleListener.self) { container in
            TagRetryLifecycleListener(
                uploader: try await container.resolve(TagUploaderProtocol.self)
            )
        }
    }
}
