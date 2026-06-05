import Foundation

public struct KairoLiveStoreComponents: Sendable {
    public var memoryStore: any MemoryStore
    public var auditLogger: any AuditLogger
    public var chatHistoryStore: any ChatHistoryStore
    public var shareIngestionQueue: any ShareIngestionQueue
    public var sharedFilesDirectory: URL
    public var kairoRecipeStore: any KairoRecipeStore

    public init(
        memoryStore: any MemoryStore,
        auditLogger: any AuditLogger,
        chatHistoryStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        sharedFilesDirectory: URL,
        kairoRecipeStore: any KairoRecipeStore
    ) {
        self.memoryStore = memoryStore
        self.auditLogger = auditLogger
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.sharedFilesDirectory = sharedFilesDirectory
        self.kairoRecipeStore = kairoRecipeStore
    }
}

public struct KairoLiveStoreFactory: Sendable {
    public var paths: KairoPaths

    public init(paths: KairoPaths) {
        self.paths = paths
    }

    public func makeComponents() async throws -> KairoLiveStoreComponents {
        KairoLiveStoreComponents(
            memoryStore: try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL),
            auditLogger: try await FileBackedAuditLogger(fileURL: paths.auditLogURL),
            chatHistoryStore: try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL),
            shareIngestionQueue: try await JSONFileShareIngestionQueue(fileURL: paths.shareIngestionQueueURL),
            sharedFilesDirectory: paths.sharedFilesDirectory,
            kairoRecipeStore: try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
        )
    }
}
