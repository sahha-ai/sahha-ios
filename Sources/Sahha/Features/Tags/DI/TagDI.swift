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
        await container.register(TagDeadLetterQueue.self) { _ in
            TagDeadLetterQueue(
                baseDirectory: StorageDirectories.tags,
                maxStoredBatches: 500
            )
        }
        await container.register(SentTagStore.self) { container in
            SentTagStore(
                storage: try await container.resolve(UserDefaultsStorageProtocol.self)
            )
        }
        await container.register(TagPriorityAssignerProtocol.self) { _ in
            DefaultTagPriorityAssigner()
        }

        await container.register(TagUploaderProtocol.self) { container in
            TagUploader(
                tagService: try await container.resolve(TagServiceProtocol.self),
                requestMapper: try await container.resolve(TagRequestMapperProtocol.self),
                logger: try await container.resolve(ErrorLoggerProtocol.self),
                circuitBreaker: CircuitBreaker(),
                networkMonitor: NetworkMonitor(),
                persistentQueue: try await container.resolve(TagDeadLetterQueue.self),
                streamingProcessor: StreamingTagBatchProcessor(
                    requestMapper: try await container.resolve(TagRequestMapperProtocol.self),
                    priorityAssigner: try await container.resolve(TagPriorityAssignerProtocol.self),
                    config: .default
                ),
                sentTagStore: try await container.resolve(SentTagStore.self)
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

final class DefaultTagPriorityAssigner: TagPriorityAssignerProtocol {
    func assignPriority(to tag: Tag) -> TagPriority {
        .normal
    }
}
