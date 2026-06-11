import Foundation

public struct KairoLiveStoreComponents: Sendable {
    public var memoryStore: any MemoryStore
    public var knowledgeAssetStore: any KnowledgeAssetStore
    public var auditLogger: any AuditLogger
    public var chatHistoryStore: any ChatHistoryStore
    public var shareIngestionQueue: any ShareIngestionQueue
    public var sharedFilesDirectory: URL
    public var kairoRecipeStore: any KairoRecipeStore
    public var infoPageStore: any InfoPageStore
    public var chatAttachmentsDirectory: URL

    public init(
        memoryStore: any MemoryStore,
        knowledgeAssetStore: any KnowledgeAssetStore,
        auditLogger: any AuditLogger,
        chatHistoryStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        sharedFilesDirectory: URL,
        kairoRecipeStore: any KairoRecipeStore,
        infoPageStore: any InfoPageStore,
        chatAttachmentsDirectory: URL
    ) {
        self.memoryStore = memoryStore
        self.knowledgeAssetStore = knowledgeAssetStore
        self.auditLogger = auditLogger
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.sharedFilesDirectory = sharedFilesDirectory
        self.kairoRecipeStore = kairoRecipeStore
        self.infoPageStore = infoPageStore
        self.chatAttachmentsDirectory = chatAttachmentsDirectory
    }
}

public struct KairoLiveStoreFactory: Sendable {
    public var paths: KairoPaths

    public init(paths: KairoPaths) {
        self.paths = paths
    }

    public func makeComponents() async throws -> KairoLiveStoreComponents {
        let infoPageStore: any InfoPageStore
        do {
            infoPageStore = try await JSONFileInfoPageStore(fileURL: paths.infoPageStoreURL)
        } catch {
            infoPageStore = InMemoryInfoPageStore()
        }
        let chatAttachmentsDirectory = paths.knowledgeAssetsDirectory
            .appendingPathComponent("ChatAttachments", isDirectory: true)
        return KairoLiveStoreComponents(
            memoryStore: try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL),
            knowledgeAssetStore: try await JSONFileKnowledgeAssetStore(fileURL: paths.knowledgeAssetStoreURL),
            auditLogger: try await FileBackedAuditLogger(fileURL: paths.auditLogURL),
            chatHistoryStore: try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL),
            shareIngestionQueue: try await JSONFileShareIngestionQueue(fileURL: paths.shareIngestionQueueURL),
            sharedFilesDirectory: paths.sharedFilesDirectory,
            kairoRecipeStore: try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL),
            infoPageStore: infoPageStore,
            chatAttachmentsDirectory: chatAttachmentsDirectory
        )
    }
}
