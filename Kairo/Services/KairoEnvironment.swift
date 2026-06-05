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

        let skillStore = try await FileBackedAgentSkillStore(
            fileURL: rootDirectory
                .appendingPathComponent("Skills", isDirectory: true)
                .appendingPathComponent("agent-skills.json")
        )
        let skillManagerService = AgentSkillManagerService(
            store: skillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                grantedEntitlements: [],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: []
            )
        )
        if seedInstalledWeatherSkill {
            try await skillStore.upsert(uiTestingInstalledWeatherSkill(version: "2.0.0"))
        }
        let marketplaceCatalogService = try uiTestingMarketplaceCatalogService()
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
        let credentialStore = InMemoryCredentialStore()
        let oauthCallbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: rootDirectory
                .appendingPathComponent("OAuth", isDirectory: true)
                .appendingPathComponent("callback-previews.json")
        )
        let kairoRecipeStore = try await FileBackedKairoRecipeStore(
            fileURL: rootDirectory
                .appendingPathComponent("Recipes", isDirectory: true)
                .appendingPathComponent("kairo-recipes.json")
        )
        let memoryStore = InMemoryMemoryStore()
        let auditLogger = InMemoryAuditLogger()
        let shareIngestionQueue = KairoUITestingShareImportFactory(
            seedSharedTaskText: seedSharedTaskText
        ).makeQueue()
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

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: localModelComponents.aiProvider,
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            kairoRecipeStore: kairoRecipeStore,
            permissionService: StubPermissionService(),
            auditLogger: auditLogger,
            oauthConnectorCallbackStore: oauthCallbackStore,
            agentSkillManagerService: skillManagerService,
            agentSkillMarketplaceCatalogService: marketplaceCatalogService,
            localModelCatalog: localModelComponents.catalog,
            localModelCatalogService: localModelComponents.catalogService,
            localModelSettingsService: localModelComponents.settingsService,
            localModelBenchmarkService: localModelComponents.benchmarkService,
            localModelReplyCheckService: localModelComponents.replyCheckService,
            localModelChatRuntimeAvailable: localModelComponents.chatRuntimeAvailable,
            actionExecutor: SandboxActionExecutor(
                memoryStore: memoryStore,
                reminderScheduler: AllowingReminderScheduler(identifier: "ui-testing-reminder-id"),
                calendarScheduler: AllowingCalendarScheduler(identifier: "ui-testing-calendar-event-id"),
                contactScheduler: AllowingContactScheduler(identifier: "ui-testing-contact-id"),
                urlOpener: AllowingURLOpener(),
                notificationScheduler: AllowingNotificationScheduler(identifier: "ui-testing-notification-id"),
                auditLogger: auditLogger
            )
        )
    }

    private static func uiTestingMarketplaceCatalogService() throws -> AgentSkillMarketplaceCatalogService {
        let indexURL = AgentSkillMarketplaceCatalogService.defaultIndexURL
        let manifestURL = URL(string: "manifests/weather-briefing.json", relativeTo: indexURL)!.absoluteURL
        let qwenWorkflowManifestURL = URL(string: "manifests/qwen-oauth-workflow.json", relativeTo: indexURL)!.absoluteURL
        var weatherSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: manifestURL
        )
        weatherSkill.version = "2.1.0"
        weatherSkill.author = "Kairo Marketplace"

        let manifest = try AgentSkillManifest(
            skill: weatherSkill,
            packageVersion: "2026.6",
            checksum: AgentSkillManifest.sha256Hex(for: weatherSkill),
            signature: AgentSkillManifestSignature(
                keyID: "kairo-test-key",
                algorithm: .ed25519,
                value: "test-signature"
            ),
            changelog: ["Adds storm alerts."]
        )
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        var qwenWorkflowSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: qwenWorkflowManifestURL
        )
        qwenWorkflowSkill.version = "1.0.0"
        qwenWorkflowSkill.author = "Kairo Marketplace"
        qwenWorkflowSkill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let qwenWorkflowManifest = try AgentSkillManifest.signedForTesting(
            skill: qwenWorkflowSkill,
            packageVersion: "2026.6"
        )
        let qwenWorkflowManifestJSON = try AgentSkillManifest.encodeJSONString(qwenWorkflowManifest)
        let indexJSON = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
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
            },
            {
              "id": "marketplace-qwen-oauth-workflow",
              "displayName": "Qwen OAuth Workflow",
              "summary": "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
              "version": "1.0.0",
              "author": "Kairo Marketplace",
              "category": "Local Model",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 2: local model plus OAuth-gated request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/qwen-oauth-workflow.json",
              "screenshots": ["assets/shortcut-toolkit-card.svg"],
              "changelog": ["Adds compatibility gates for OAuth and local model availability."],
              "compatibilityRequirements": {
                "requiredOAuthProviderKeys": ["google"],
                "requiredLocalModelIDs": ["qwen3-5-0-8b-q4-k-m"]
              }
            }
          ]
        }
        """
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: indexJSON),
            manifestURL: StaticHTTPResponse(body: manifestJSON),
            qwenWorkflowManifestURL: StaticHTTPResponse(body: qwenWorkflowManifestJSON)
        ])

        return AgentSkillMarketplaceCatalogService(indexURL: indexURL, httpClient: httpClient)
    }

    private static func uiTestingInstalledWeatherSkill(version: String) -> AgentSkill {
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(
                string: "manifests/weather-briefing.json",
                relativeTo: AgentSkillMarketplaceCatalogService.defaultIndexURL
            )!.absoluteURL
        )
        skill.version = version
        skill.author = "Kairo Marketplace"
        skill.installationStatus = .installed
        return skill
    }

    public static func live(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier,
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier)
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let auditLogger = try await FileBackedAuditLogger(fileURL: paths.auditLogURL)
        let chatHistoryStore = try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL)
        let shareIngestionQueue = try await JSONFileShareIngestionQueue(fileURL: paths.shareIngestionQueueURL)
        let kairoRecipeStore = try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
        let agentSkillStore = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
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
        #if os(macOS)
        let localModelCommandRuntime = LocalModelExternalCommandRuntime(
            configuration: .llamaCLI(
                executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/llama-cli")
            ),
            commandRunner: ProcessLocalModelCommandRunner()
        )
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore,
            engine: localModelBenchmarkEngineOverride ?? localModelCommandRuntime
        )
        let localModelReplyRuntime = localModelReplyCheckRuntimeOverride ?? localModelCommandRuntime
        let localModelReplyCheckService = LocalModelReplyCheckService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            runtime: localModelReplyRuntime
        )
        let localModelChatRuntimeAvailable = true
        #else
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore,
            engine: localModelBenchmarkEngineOverride ?? UnavailableLocalModelBenchmarkEngine()
        )
        let localModelReplyRuntime = localModelReplyCheckRuntimeOverride ?? UnavailableLocalModelReplyCheckRuntime()
        let localModelReplyCheckService = LocalModelReplyCheckService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            runtime: localModelReplyRuntime
        )
        let localModelChatRuntimeAvailable = localModelReplyCheckRuntimeOverride != nil
        #endif
        let credentialStore = KeychainCredentialStore()
        let aiProvider = LocalModelRoutingAIProvider(
            cloudProvider: OpenAIProvider(credentialStore: credentialStore),
            localModelSettingsService: localModelSettingsService,
            localProvider: LocalModelRuntimeAIProvider(
                localModelSettingsService: localModelSettingsService,
                runtime: localModelReplyRuntime
            ),
            localRuntimeAvailable: localModelChatRuntimeAvailable
        )
        let connectedOAuthProviderKeys = try await connectedOAuthProviderKeys(credentialStore: credentialStore)
        let runtimeContext = AgentSkillRuntimeContext.current(
            grantedEntitlements: [],
            connectedOAuthProviderKeys: connectedOAuthProviderKeys,
            installedLocalModelIDs: await localModelInstallRegistry.installedRecords().map(\.modelID)
        )
        let agentSkillManagerService = AgentSkillManagerService(
            store: agentSkillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            trustStore: .defaultRelease,
            runtimeContext: runtimeContext
        )
        let agentSkillMarketplaceCatalogService = AgentSkillMarketplaceCatalogService.defaultStandaloneRepository
        let localModelCatalogService = LocalModelCatalogService.defaultStandaloneRepository
        let oauthCallbackStore = try await FileBackedOAuthConnectorCallbackStore(fileURL: paths.oauthConnectorCallbackPreviewsURL)
        let oauthClientConfigurations = OAuthConnectorClientConfigurationLoader().load()
        #if canImport(UIKit)
        let urlOpener: any URLOpener = UIApplicationURLOpener()
        #else
        let urlOpener: any URLOpener = NoOpURLOpener()
        #endif
        let actionExecutor: any ActionExecutor
        #if canImport(UserNotifications)
        actionExecutor = SandboxActionExecutor(
            memoryStore: memoryStore,
            urlOpener: urlOpener,
            notificationScheduler: UserNotificationScheduler(),
            auditLogger: auditLogger
        )
        #else
        actionExecutor = SandboxActionExecutor(
            memoryStore: memoryStore,
            urlOpener: urlOpener,
            auditLogger: auditLogger
        )
        #endif

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            sharedFilesDirectory: paths.sharedFilesDirectory,
            kairoRecipeStore: kairoRecipeStore,
            permissionService: SystemPermissionService(),
            auditLogger: auditLogger,
            oauthConnectorCallbackStore: oauthCallbackStore,
            oauthClientConfigurations: oauthClientConfigurations,
            agentSkillManagerService: agentSkillManagerService,
            agentSkillMarketplaceCatalogService: agentSkillMarketplaceCatalogService,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelDownloader: localModelDownloader,
            localModelBenchmarkService: localModelBenchmarkService,
            localModelReplyCheckService: localModelReplyCheckService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionExecutor: actionExecutor
        )
    }

    static func connectedOAuthProviderKeys(credentialStore: CredentialStore) async throws -> [String] {
        var providerKeys: [String] = []
        for integration in IntegrationRegistry().oauthConnectors {
            guard let providerKey = integration.oauth?.providerKey else { continue }
            guard let encoded = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: providerKey)) else {
                continue
            }
            if let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded),
               !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerKeys.append(providerKey)
            }
        }
        return Array(Set(providerKeys)).sorted()
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
