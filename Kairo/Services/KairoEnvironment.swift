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

public struct KairoEnvironment: KairoBackendDependencies {
    public let memoryStore: MemoryStore
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let chatHistoryStore: ChatHistoryStore
    public let shareIngestionQueue: ShareIngestionQueue
    public let sharedFilesDirectory: URL?
    public let kairoRecipeStore: any KairoRecipeStore
    public let permissionService: PermissionService
    public let auditLogger: AuditLogger
    public let oauthConnectorCallbackStore: FileBackedOAuthConnectorCallbackStore?
    public let oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]
    public let agentSkillManagerService: AgentSkillManagerService?
    public let agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    public let localModelCatalog: LocalModelCatalog
    public let localModelCatalogService: LocalModelCatalogService?
    public let localModelSettingsService: LocalModelSettingsService?
    public let localModelDownloader: (any LocalModelDownloader)?
    public let localModelBenchmarkService: LocalModelBenchmarkService?
    public let localModelReplyCheckService: LocalModelReplyCheckService?
    public let localModelChatRuntimeAvailable: Bool
    public let actionExecutor: any ActionExecutor

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        chatHistoryStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        sharedFilesDirectory: URL? = nil,
        kairoRecipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger(),
        oauthConnectorCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        agentSkillManagerService: AgentSkillManagerService? = nil,
        agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        localModelChatRuntimeAvailable: Bool = false,
        actionExecutor: (any ActionExecutor)? = nil
    ) {
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.sharedFilesDirectory = sharedFilesDirectory
        self.kairoRecipeStore = kairoRecipeStore
        self.permissionService = permissionService
        self.auditLogger = auditLogger
        self.oauthConnectorCallbackStore = oauthConnectorCallbackStore
        self.oauthClientConfigurations = oauthClientConfigurations
        self.agentSkillManagerService = agentSkillManagerService
        self.agentSkillMarketplaceCatalogService = agentSkillMarketplaceCatalogService
        self.localModelCatalog = localModelCatalog
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.localModelChatRuntimeAvailable = localModelChatRuntimeAvailable
        self.actionExecutor = actionExecutor ?? SandboxActionExecutor(memoryStore: memoryStore, auditLogger: auditLogger)
    }

    public static func preview() -> KairoEnvironment {
        let credentialStore = InMemoryCredentialStore()
        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [ChatThread(messages: [
                ChatMessage(role: .assistant, text: KairoL10n.string("chat.welcome.preview"))
            ])]),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            kairoRecipeStore: InMemoryKairoRecipeStore(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    public static func uiTesting(
        resetPersistentState: Bool = true,
        seedInstalledLocalModel: Bool = false,
        seedInstalledWeatherSkill: Bool = false,
        seedExpandedLocalModelCatalog: Bool = false,
        seedSharedTaskText: Bool = false,
        selectInstalledLocalModel: Bool = false,
        localModelRoutePreference: ProviderRoutePreference? = nil,
        installedLocalModelFileURL: URL? = nil,
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) async throws -> KairoEnvironment {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoUITesting", isDirectory: true)
        if resetPersistentState {
            try? FileManager.default.removeItem(at: rootDirectory)
        }

        let skillComponents = try await KairoUITestingSkillFactory(
            rootDirectory: rootDirectory,
            seedInstalledWeatherSkill: seedInstalledWeatherSkill
        ).makeComponents()
        let localModelComponents = try await KairoUITestingLocalModelFactory(
            rootDirectory: rootDirectory,
            seedInstalledLocalModel: seedInstalledLocalModel,
            seedExpandedLocalModelCatalog: seedExpandedLocalModelCatalog,
            selectInstalledLocalModel: selectInstalledLocalModel,
            routePreference: localModelRoutePreference,
            installedLocalModelFileURL: installedLocalModelFileURL,
            replyCheckRuntimeOverride: localModelReplyCheckRuntimeOverride,
            benchmarkEngineOverride: localModelBenchmarkEngineOverride
        ).makeComponents()
        let storeComponents = try await KairoUITestingStoreFactory(
            rootDirectory: rootDirectory,
            seedSharedTaskText: seedSharedTaskText
        ).makeComponents()
        let credentialStore = InMemoryCredentialStore()

        return KairoEnvironment(
            memoryStore: storeComponents.memoryStore,
            credentialStore: credentialStore,
            aiProvider: localModelComponents.aiProvider,
            chatHistoryStore: storeComponents.chatHistoryStore,
            shareIngestionQueue: storeComponents.shareIngestionQueue,
            kairoRecipeStore: storeComponents.kairoRecipeStore,
            permissionService: StubPermissionService(),
            auditLogger: storeComponents.auditLogger,
            oauthConnectorCallbackStore: storeComponents.oauthCallbackStore,
            agentSkillManagerService: skillComponents.managerService,
            agentSkillMarketplaceCatalogService: skillComponents.marketplaceCatalogService,
            localModelCatalog: localModelComponents.catalog,
            localModelCatalogService: localModelComponents.catalogService,
            localModelSettingsService: localModelComponents.settingsService,
            localModelBenchmarkService: localModelComponents.benchmarkService,
            localModelReplyCheckService: localModelComponents.replyCheckService,
            localModelChatRuntimeAvailable: localModelComponents.chatRuntimeAvailable,
            actionExecutor: SandboxActionExecutor(
                memoryStore: storeComponents.memoryStore,
                reminderScheduler: AllowingReminderScheduler(identifier: "ui-testing-reminder-id"),
                calendarScheduler: AllowingCalendarScheduler(identifier: "ui-testing-calendar-event-id"),
                contactScheduler: AllowingContactScheduler(identifier: "ui-testing-contact-id"),
                urlOpener: AllowingURLOpener(),
                notificationScheduler: AllowingNotificationScheduler(identifier: "ui-testing-notification-id"),
                auditLogger: storeComponents.auditLogger
            )
        )
    }

    public static func live(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier,
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier)
        let storeComponents = try await KairoLiveStoreFactory(paths: paths).makeComponents()
        let credentialStore = KeychainCredentialStore()
        let localModelComponents = try await KairoLiveLocalModelFactory(
            paths: paths,
            credentialStore: credentialStore,
            replyCheckRuntimeOverride: localModelReplyCheckRuntimeOverride,
            benchmarkEngineOverride: localModelBenchmarkEngineOverride
        ).makeComponents()
        let accessComponents = try await KairoLiveAccessFactory(
            paths: paths,
            credentialStore: credentialStore,
            installedLocalModelIDs: localModelComponents.installedModelIDs
        ).makeComponents()
        let actionExecutor = KairoLiveActionFactory(
            memoryStore: storeComponents.memoryStore,
            auditLogger: storeComponents.auditLogger
        ).makeActionExecutor()

        return KairoEnvironment(
            memoryStore: storeComponents.memoryStore,
            credentialStore: credentialStore,
            aiProvider: localModelComponents.aiProvider,
            chatHistoryStore: storeComponents.chatHistoryStore,
            shareIngestionQueue: storeComponents.shareIngestionQueue,
            sharedFilesDirectory: storeComponents.sharedFilesDirectory,
            kairoRecipeStore: storeComponents.kairoRecipeStore,
            permissionService: SystemPermissionService(),
            auditLogger: storeComponents.auditLogger,
            oauthConnectorCallbackStore: accessComponents.oauthCallbackStore,
            oauthClientConfigurations: accessComponents.oauthClientConfigurations,
            agentSkillManagerService: accessComponents.skillManagerService,
            agentSkillMarketplaceCatalogService: accessComponents.marketplaceCatalogService,
            localModelCatalog: localModelComponents.catalog,
            localModelCatalogService: localModelComponents.catalogService,
            localModelSettingsService: localModelComponents.settingsService,
            localModelDownloader: localModelComponents.downloader,
            localModelBenchmarkService: localModelComponents.benchmarkService,
            localModelReplyCheckService: localModelComponents.replyCheckService,
            localModelChatRuntimeAvailable: localModelComponents.chatRuntimeAvailable,
            actionExecutor: actionExecutor
        )
    }

    static func connectedOAuthProviderKeys(credentialStore: CredentialStore) async throws -> [String] {
        try await KairoLiveAccessFactory.connectedOAuthProviderKeys(credentialStore: credentialStore)
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

    public var auditLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("audit-log.json")
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

    public var kairoRecipesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Recipes", isDirectory: true)
    }

    public var kairoRecipeStoreURL: URL {
        kairoRecipesDirectory.appendingPathComponent("kairo-recipes.json")
    }

    public var agentSkillsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Skills", isDirectory: true)
    }

    public var agentSkillStoreURL: URL {
        agentSkillsDirectory.appendingPathComponent("agent-skills.json")
    }

    public var oauthConnectorCallbackPreviewsURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("OAuth", isDirectory: true)
            .appendingPathComponent("callback-previews.json")
    }

    public static func defaultAppGroupContainerURL(for identifier: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
