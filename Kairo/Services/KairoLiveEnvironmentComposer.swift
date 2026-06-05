import Foundation

public struct KairoLiveEnvironmentComposer: Sendable {
    public var paths: KairoPaths
    public var credentialStore: any CredentialStore
    public var oauthConnectorRegistry: any OAuthConnectorRegistryProviding
    public var oauthLoginServiceFactory: any OAuthConnectorLoginServiceMaking
    public var toolCatalog: any BuiltInPhoneToolCatalogProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var capabilityRegistry: any CapabilityRegistryProviding
    public var actionSafetyPolicy: any ActionSafetyPolicyEvaluating
    public var localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)?
    public var localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)?

    public init(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier,
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        oauthConnectorRegistry: any OAuthConnectorRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        oauthLoginServiceFactory: any OAuthConnectorLoginServiceMaking = OAuthConnectorLoginServiceFactory(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry(),
        actionSafetyPolicy: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine(),
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.init(
            paths: KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier),
            credentialStore: credentialStore,
            oauthConnectorRegistry: oauthConnectorRegistry,
            oauthLoginServiceFactory: oauthLoginServiceFactory,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            capabilityRegistry: capabilityRegistry,
            actionSafetyPolicy: actionSafetyPolicy,
            localModelReplyCheckRuntimeOverride: localModelReplyCheckRuntimeOverride,
            localModelBenchmarkEngineOverride: localModelBenchmarkEngineOverride
        )
    }

    public init(
        paths: KairoPaths,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any OAuthConnectorRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        oauthLoginServiceFactory: any OAuthConnectorLoginServiceMaking = OAuthConnectorLoginServiceFactory(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry(),
        actionSafetyPolicy: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine(),
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.oauthConnectorRegistry = oauthConnectorRegistry
        self.oauthLoginServiceFactory = oauthLoginServiceFactory
        self.toolCatalog = toolCatalog
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.capabilityRegistry = capabilityRegistry
        self.actionSafetyPolicy = actionSafetyPolicy
        self.localModelReplyCheckRuntimeOverride = localModelReplyCheckRuntimeOverride
        self.localModelBenchmarkEngineOverride = localModelBenchmarkEngineOverride
    }

    public func makeEnvironment() async throws -> KairoEnvironment {
        let storeComponents = try await KairoLiveStoreFactory(paths: paths).makeComponents()
        let localModelComponents = try await KairoLiveLocalModelFactory(
            paths: paths,
            credentialStore: credentialStore,
            replyCheckRuntimeOverride: localModelReplyCheckRuntimeOverride,
            benchmarkEngineOverride: localModelBenchmarkEngineOverride
        ).makeComponents()
        let integrationRegistry = IntegrationRegistry.appIntegrationHarnessRegistry(
            legacyRegistry: oauthConnectorRegistry,
            catalog: appIntegrationSkillCatalog
        )
        let accessComponents = try await KairoLiveAccessFactory(
            paths: paths,
            credentialStore: credentialStore,
            installedLocalModelIDs: localModelComponents.installedModelIDs,
            oauthConnectorRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        ).makeComponents()
        let shortcutRuntime = try await LiveShortcutNodeRuntimeProvider(
            paths: paths,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        ).makeRuntime()
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
            oauthConnectorRegistry: integrationRegistry,
            oauthConnectorCallbackStore: accessComponents.oauthCallbackStore,
            oauthClientConfigurations: accessComponents.oauthClientConfigurations,
            oauthLoginServiceFactory: oauthLoginServiceFactory,
            agentSkillManagerService: accessComponents.skillManagerService,
            agentSkillMarketplaceCatalogService: accessComponents.marketplaceCatalogService,
            localModelCatalog: localModelComponents.catalog,
            localModelCatalogService: localModelComponents.catalogService,
            localModelSettingsService: localModelComponents.settingsService,
            localModelDownloader: localModelComponents.downloader,
            localModelBenchmarkService: localModelComponents.benchmarkService,
            localModelReplyCheckService: localModelComponents.replyCheckService,
            localModelChatRuntimeAvailable: localModelComponents.chatRuntimeAvailable,
            actionExecutor: actionExecutor,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            capabilityRegistry: capabilityRegistry,
            actionSafetyPolicy: actionSafetyPolicy,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: shortcutRuntime,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            )
        )
    }
}
