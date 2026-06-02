import Foundation

public enum KairoSharedAppStorage {
    public static let appName = "Kairo"
    public static let appGroupIdentifier = "group.app.kairo.shared"

    public static func paths(
        appName: String = KairoSharedAppStorage.appName,
        appGroupContainerProvider: (@Sendable (String) -> URL?)? = nil
    ) -> KairoPaths {
        KairoPaths(
            appName: appName,
            appGroupIdentifier: appGroupIdentifier,
            appGroupContainerProvider: appGroupContainerProvider
        )
    }
}

public struct KairoEnvironment: Sendable {
    public let memoryStore: MemoryStore
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let chatHistoryStore: ChatHistoryStore
    public let shareIngestionQueue: ShareIngestionQueue
    public let permissionService: PermissionService
    public let auditLogger: AuditLogger
    public let agentSkillManagerService: AgentSkillManagerService?
    public let agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService?

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        chatHistoryStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger(),
        agentSkillManagerService: AgentSkillManagerService? = nil,
        agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil
    ) {
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.permissionService = permissionService
        self.auditLogger = auditLogger
        self.agentSkillManagerService = agentSkillManagerService
        self.agentSkillMarketplaceCatalogService = agentSkillMarketplaceCatalogService
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
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    public static func live(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier
    ) async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier)
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let chatHistoryStore = try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL)
        let shareIngestionQueue = try await JSONFileShareIngestionQueue(fileURL: paths.shareIngestionQueueURL)
        let agentSkillStore = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
        let agentSkillManagerService = AgentSkillManagerService(
            store: agentSkillStore,
            builtInCatalog: .defaultWithMarketplaceSamples
        )
        let credentialStore = KeychainCredentialStore()
        let aiProvider = OpenAIProvider(credentialStore: credentialStore)
        let agentSkillMarketplaceCatalogService = AgentSkillMarketplaceCatalogService.defaultStandaloneRepository

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            permissionService: SystemPermissionService(),
            auditLogger: InMemoryAuditLogger(),
            agentSkillManagerService: agentSkillManagerService,
            agentSkillMarketplaceCatalogService: agentSkillMarketplaceCatalogService
        )
    }
}

public struct KairoPaths: Sendable {
    public let appName: String
    public let appGroupIdentifier: String?
    private let appGroupContainerProvider: @Sendable (String) -> URL?

    public init(
        appName: String = "Kairo",
        appGroupIdentifier: String? = nil,
        appGroupContainerProvider: (@Sendable (String) -> URL?)? = nil
    ) {
        self.appName = appName
        self.appGroupIdentifier = appGroupIdentifier
        self.appGroupContainerProvider = appGroupContainerProvider ?? { identifier in
            Self.defaultAppGroupContainerURL(for: identifier)
        }
    }

    public var applicationSupportDirectory: URL {
        if let appGroupDirectory {
            return appGroupDirectory.appendingPathComponent(appName, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    public var appGroupDirectory: URL? {
        guard let appGroupIdentifier else { return nil }
        return appGroupContainerProvider(appGroupIdentifier)
    }

    public var usesAppGroup: Bool {
        appGroupDirectory != nil
    }

    public var memoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("memory-store.json")
    }

    public var chatHistoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("chat-history.json")
    }

    public var shareIngestionQueueURL: URL {
        applicationSupportDirectory.appendingPathComponent("share-ingestion-queue.json")
    }

    public var sharedFilesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
    }

    public var localModelsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("LocalModels", isDirectory: true)
    }

    public var localModelInstallRegistryURL: URL {
        localModelsDirectory.appendingPathComponent("install-registry.json")
    }

    public var localModelSettingsURL: URL {
        localModelsDirectory.appendingPathComponent("settings.json")
    }

    public var agentSkillsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Skills", isDirectory: true)
    }

    public var agentSkillStoreURL: URL {
        agentSkillsDirectory.appendingPathComponent("agent-skills.json")
    }

    public static func defaultAppGroupContainerURL(for identifier: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
