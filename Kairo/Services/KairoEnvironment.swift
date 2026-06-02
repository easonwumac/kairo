import Foundation

public struct KairoEnvironment: Sendable {
    public let memoryStore: MemoryStore
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let chatHistoryStore: ChatHistoryStore
    public let permissionService: PermissionService
    public let auditLogger: AuditLogger

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        chatHistoryStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger()
    ) {
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.chatHistoryStore = chatHistoryStore
        self.permissionService = permissionService
        self.auditLogger = auditLogger
    }

    public static func preview() -> KairoEnvironment {
        let credentialStore = InMemoryCredentialStore()
        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [ChatThread(messages: [
                ChatMessage(role: .assistant, text: "我是 Kairo。我會記住你選擇交給我的內容，並只操作 iOS sandbox 與公開 API 允許的能力。")
            ])]),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    public static func live(appName: String = "Kairo") async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName)
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let chatHistoryStore = try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL)
        let credentialStore = KeychainCredentialStore()
        let aiProvider = OpenAIProvider(credentialStore: credentialStore)

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            chatHistoryStore: chatHistoryStore,
            permissionService: SystemPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }
}

public struct KairoPaths: Sendable {
    public let appName: String

    public init(appName: String = "Kairo") {
        self.appName = appName
    }

    public var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    public var memoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("memory-store.json")
    }

    public var chatHistoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("chat-history.json")
    }

    public var localModelsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("LocalModels", isDirectory: true)
    }

    public var localModelInstallRegistryURL: URL {
        localModelsDirectory.appendingPathComponent("install-registry.json")
    }
}
