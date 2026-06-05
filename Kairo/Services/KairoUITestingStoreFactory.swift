import Foundation

public struct KairoUITestingStoreComponents: Sendable {
    public var memoryStore: any MemoryStore
    public var auditLogger: any AuditLogger
    public var chatHistoryStore: any ChatHistoryStore
    public var shareIngestionQueue: any ShareIngestionQueue
    public var kairoRecipeStore: any KairoRecipeStore
    public var oauthCallbackStore: FileBackedOAuthConnectorCallbackStore

    public init(
        memoryStore: any MemoryStore,
        auditLogger: any AuditLogger,
        chatHistoryStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        kairoRecipeStore: any KairoRecipeStore,
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore
    ) {
        self.memoryStore = memoryStore
        self.auditLogger = auditLogger
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.kairoRecipeStore = kairoRecipeStore
        self.oauthCallbackStore = oauthCallbackStore
    }
}

public struct KairoUITestingStoreFactory: Sendable {
    public var rootDirectory: URL
    public var seedSharedTaskText: Bool

    public init(rootDirectory: URL, seedSharedTaskText: Bool = false) {
        self.rootDirectory = rootDirectory
        self.seedSharedTaskText = seedSharedTaskText
    }

    public func makeComponents() async throws -> KairoUITestingStoreComponents {
        let chatHistoryStore = try await JSONFileChatHistoryStore(
            fileURL: rootDirectory
                .appendingPathComponent("Chat", isDirectory: true)
                .appendingPathComponent("chat-history.json")
        )
        if try await chatHistoryStore.listThreads(limit: 1).isEmpty {
            try await chatHistoryStore.saveThread(ChatThread(messages: [
                ChatMessage(role: .assistant, text: "UI testing Kairo environment loaded.")
            ]))
        }

        return KairoUITestingStoreComponents(
            memoryStore: InMemoryMemoryStore(),
            auditLogger: InMemoryAuditLogger(),
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: KairoUITestingShareImportFactory(
                seedSharedTaskText: seedSharedTaskText
            ).makeQueue(),
            kairoRecipeStore: try await FileBackedKairoRecipeStore(
                fileURL: rootDirectory
                    .appendingPathComponent("Recipes", isDirectory: true)
                    .appendingPathComponent("kairo-recipes.json")
            ),
            oauthCallbackStore: try await FileBackedOAuthConnectorCallbackStore(
                fileURL: rootDirectory
                    .appendingPathComponent("OAuth", isDirectory: true)
                    .appendingPathComponent("callback-previews.json")
            )
        )
    }
}
