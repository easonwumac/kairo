import Foundation

public struct KairoUITestingEnvironmentComposer: Sendable {
    public var rootDirectory: URL
    public var resetPersistentState: Bool
    public var seedInstalledLocalModel: Bool
    public var seedInstalledWeatherSkill: Bool
    public var seedExpandedLocalModelCatalog: Bool
    public var seedSharedTaskText: Bool
    public var selectInstalledLocalModel: Bool
    public var localModelRoutePreference: ProviderRoutePreference?
    public var installedLocalModelFileURL: URL?
    public var localModelReplyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)?
    public var localModelBenchmarkEngineOverride: (any LocalModelBenchmarkEngine)?

    public init(
        rootDirectory: URL = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoUITesting", isDirectory: true),
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
    ) {
        self.rootDirectory = rootDirectory
        self.resetPersistentState = resetPersistentState
        self.seedInstalledLocalModel = seedInstalledLocalModel
        self.seedInstalledWeatherSkill = seedInstalledWeatherSkill
        self.seedExpandedLocalModelCatalog = seedExpandedLocalModelCatalog
        self.seedSharedTaskText = seedSharedTaskText
        self.selectInstalledLocalModel = selectInstalledLocalModel
        self.localModelRoutePreference = localModelRoutePreference
        self.installedLocalModelFileURL = installedLocalModelFileURL
        self.localModelReplyCheckRuntimeOverride = localModelReplyCheckRuntimeOverride
        self.localModelBenchmarkEngineOverride = localModelBenchmarkEngineOverride
    }

    public func makeEnvironment() async throws -> KairoEnvironment {
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
            actionExecutor: KairoUITestingActionFactory(
                memoryStore: storeComponents.memoryStore,
                auditLogger: storeComponents.auditLogger
            ).makeActionExecutor()
        )
    }
}
