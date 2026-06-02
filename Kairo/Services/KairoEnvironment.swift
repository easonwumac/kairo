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
    public let localModelCatalog: LocalModelCatalog
    public let localModelCatalogService: LocalModelCatalogService?
    public let localModelSettingsService: LocalModelSettingsService?
    public let localModelDownloader: (any LocalModelDownloader)?
    public let localModelBenchmarkService: LocalModelBenchmarkService?

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        chatHistoryStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger(),
        agentSkillManagerService: AgentSkillManagerService? = nil,
        agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil
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
        self.localModelCatalog = localModelCatalog
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
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

    public static func uiTesting(resetPersistentState: Bool = true) async throws -> KairoEnvironment {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoUITesting", isDirectory: true)
        if resetPersistentState {
            try? FileManager.default.removeItem(at: rootDirectory)
        }

        let skillStore = try await FileBackedAgentSkillStore(
            fileURL: rootDirectory
                .appendingPathComponent("Skills", isDirectory: true)
                .appendingPathComponent("agent-skills.json")
        )
        let skillManagerService = AgentSkillManagerService(
            store: skillStore,
            builtInCatalog: .defaultWithMarketplaceSamples
        )
        let marketplaceCatalogService = try uiTestingMarketplaceCatalogService()
        let localModelCatalogService = try uiTestingLocalModelCatalogService()
        let localModelInstallRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("install-registry.json")
        )
        let localModelSettingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("settings.json")
        )
        let localModelSettingsService = LocalModelSettingsService(
            catalog: .kairoDefault,
            installRegistry: localModelInstallRegistry,
            settingsStore: localModelSettingsStore
        )
        let localModelBenchmarkStore = try await FileBackedLocalModelBenchmarkStore(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("benchmarks.json")
        )
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore
        )
        let credentialStore = InMemoryCredentialStore()

        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [ChatThread(messages: [
                ChatMessage(role: .assistant, text: "UI testing Kairo environment loaded.")
            ])]),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger(),
            agentSkillManagerService: skillManagerService,
            agentSkillMarketplaceCatalogService: marketplaceCatalogService,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelBenchmarkService: localModelBenchmarkService
        )
    }

    private static func uiTestingMarketplaceCatalogService() throws -> AgentSkillMarketplaceCatalogService {
        let indexURL = AgentSkillMarketplaceCatalogService.defaultIndexURL
        let manifestURL = URL(string: "manifests/weather-briefing.json", relativeTo: indexURL)!.absoluteURL
        var weatherSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: manifestURL
        )
        weatherSkill.version = "2.1.0"
        weatherSkill.author = "Kairo Marketplace"

        let manifest = try AgentSkillManifest.signedForTesting(
            skill: weatherSkill,
            packageVersion: "2026.6"
        )
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        let indexJSON = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API and returns a compact daily plan.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: indexJSON),
            manifestURL: StaticHTTPResponse(body: manifestJSON)
        ])

        return AgentSkillMarketplaceCatalogService(indexURL: indexURL, httpClient: httpClient)
    }

    private static func uiTestingLocalModelCatalogService() throws -> LocalModelCatalogService {
        let indexURL = LocalModelCatalogService.defaultIndexURL
        let catalogJSON = String(data: try LocalModelCatalog.kairoDefault.encoded(), encoding: .utf8) ?? "{}"
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: catalogJSON)
        ])
        return LocalModelCatalogService(indexURL: indexURL, httpClient: httpClient)
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
        let localModelCatalog = LocalModelCatalog.kairoDefault
        let localModelInstallRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: paths.localModelInstallRegistryURL
        )
        let localModelSettingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: paths.localModelSettingsURL
        )
        let localModelSettingsService = LocalModelSettingsService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            settingsStore: localModelSettingsStore
        )
        let localModelDownloader = VerifiedLocalModelDownloader(
            installRegistry: localModelInstallRegistry,
            modelsDirectory: paths.localModelsDirectory
        )
        let localModelBenchmarkStore = try await FileBackedLocalModelBenchmarkStore(fileURL: paths.localModelBenchmarkResultsURL)
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore
        )
        let credentialStore = KeychainCredentialStore()
        let aiProvider = OpenAIProvider(credentialStore: credentialStore)
        let agentSkillMarketplaceCatalogService = AgentSkillMarketplaceCatalogService.defaultStandaloneRepository
        let localModelCatalogService = LocalModelCatalogService.defaultStandaloneRepository

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            permissionService: SystemPermissionService(),
            auditLogger: InMemoryAuditLogger(),
            agentSkillManagerService: agentSkillManagerService,
            agentSkillMarketplaceCatalogService: agentSkillMarketplaceCatalogService,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelDownloader: localModelDownloader,
            localModelBenchmarkService: localModelBenchmarkService
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

    public var localModelBenchmarkResultsURL: URL {
        localModelsDirectory.appendingPathComponent("benchmarks.json")
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
