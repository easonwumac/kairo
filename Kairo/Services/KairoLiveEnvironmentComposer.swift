import Foundation

public struct KairoLiveEnvironmentComposer: Sendable {
    public var paths: KairoPaths
    public var credentialStore: any CredentialStore
    public var localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)?
    public var localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)?

    public init(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier,
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.init(
            paths: KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier),
            credentialStore: credentialStore,
            localModelReplyCheckRuntimeOverride: localModelReplyCheckRuntimeOverride,
            localModelBenchmarkEngineOverride: localModelBenchmarkEngineOverride
        )
    }

    public init(
        paths: KairoPaths,
        credentialStore: any CredentialStore,
        localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
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
}
