import Foundation

public protocol KairoBackendDependencies: Sendable {
    var memoryStore: MemoryStore { get }
    var credentialStore: CredentialStore { get }
    var aiProvider: AIProvider { get }
    var chatHistoryStore: ChatHistoryStore { get }
    var shareIngestionQueue: ShareIngestionQueue { get }
    var sharedFilesDirectory: URL? { get }
    var actionExecutor: ActionExecutor { get }
    var kairoRecipeStore: any KairoRecipeStore { get }
    var permissionService: PermissionService { get }
    var auditLogger: AuditLogger { get }
    var oauthConnectorRegistry: any OAuthConnectorRegistryProviding { get }
    var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] { get }
    var agentSkillManagerService: AgentSkillManagerService? { get }
    var localModelSettingsService: LocalModelSettingsService? { get }
    var toolCatalog: any BuiltInPhoneToolCatalogProviding { get }
    var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding { get }
    var capabilityRegistry: CapabilityRegistry { get }
}

public protocol KairoBackendServiceMaking: Sendable {
    func makeChatAPI() -> any KairoChatAPI
    func makeMemoryAPI() -> any KairoMemoryAPI
    func makeRecipeAPI() -> any KairoRecipeAPI
    func makeShareImportAPI() -> any KairoShareImportAPI
    func makeActionAPI() -> any KairoActionAPI
    func makeDeletionAPI() -> any KairoDeletionAPI
    func makeLocalModelAPI() -> any KairoLocalModelAPI
    func makeSkillAPI() -> any KairoSkillAPI
    func makeSettingsAPI() -> any KairoSettingsAPI
    func makeAccessAPI() -> any KairoAccessAPI
}

public struct KairoSettingsBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeSettingsAPI() -> any KairoSettingsAPI {
        KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: dependencies.credentialStore),
            oauthLoginCenter: OAuthConnectorLoginServiceFactory().makeLoginService(
                override: nil,
                credentialStore: dependencies.credentialStore,
                oauthConnectorRegistry: dependencies.oauthConnectorRegistry,
                oauthClientConfigurations: dependencies.oauthClientConfigurations,
                oauthCallbackStore: nil
            )
        )
    }
}

public struct KairoAccessBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeAccessAPI() -> any KairoAccessAPI {
        KairoAccessBackendService(
            capabilityRegistry: dependencies.capabilityRegistry,
            toolCatalog: dependencies.toolCatalog,
            appIntegrationSkillCatalog: dependencies.appIntegrationSkillCatalog,
            permissionService: dependencies.permissionService
        )
    }
}

public struct KairoChatBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeChatAPI() -> any KairoChatAPI {
        KairoChatBackendService(agent: AgentCore(dependencies: makeAgentCoreDependencies()))
    }

    public func makeAgentCoreDependencies() -> AgentCoreDependencies {
        let skillCatalogProvider: AgentSkillCatalogProvider
        if let agentSkillManagerService = dependencies.agentSkillManagerService {
            skillCatalogProvider = .skillManager(agentSkillManagerService)
        } else {
            skillCatalogProvider = .default
        }
        let actionGate = BuiltInPhoneToolActionGate(toolCatalog: dependencies.toolCatalog)
        let safetyPolicyEngine = SafetyPolicyEngine()
        let toolCandidatePlanningDependencies = makeToolCandidatePlanningDependencies(
            safetyPolicyEngine: safetyPolicyEngine
        )
        return AgentCoreDependencies(
            memoryContextProvider: DefaultAgentMemoryContextProvider(memoryStore: dependencies.memoryStore),
            memoryWriter: DefaultAgentMemoryWriter(memoryStore: dependencies.memoryStore),
            aiProvider: dependencies.aiProvider,
            skillCatalogProvider: skillCatalogProvider,
            toolContextProvider: DefaultAgentCapabilityPromptContextProvider(
                capabilityRegistry: dependencies.capabilityRegistry,
                toolCatalog: dependencies.toolCatalog,
                integrationRegistry: dependencies.oauthConnectorRegistry,
                appIntegrationSkillCatalog: dependencies.appIntegrationSkillCatalog
            ),
            toolInvocationPlanner: DefaultAgentToolInvocationPlannerProvider(
                candidatePlanning: toolCandidatePlanningDependencies
            ),
            toolPlanningRequestBuilder: DefaultAgentToolPlanningRequestBuilder(),
            responseActionPlanner: DefaultAgentResponseActionPlanner(
                actionGate: actionGate,
                safetyPolicyEngine: safetyPolicyEngine
            ),
            completionRequestBuilder: DefaultAgentCompletionRequestBuilder(
                capabilityRegistry: dependencies.capabilityRegistry
            )
        )
    }

    public func makeToolCandidatePlanningDependencies(
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine()
    ) -> AgentToolCandidatePlanningDependencies {
        AgentToolCandidatePlanningDependencies(
            integrationRegistry: dependencies.oauthConnectorRegistry,
            appIntegrationSkillCatalog: dependencies.appIntegrationSkillCatalog,
            toolCatalog: dependencies.toolCatalog,
            safetyPolicyEngine: safetyPolicyEngine
        )
    }
}

public struct KairoRecipeBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeRecipeAPI() -> any KairoRecipeAPI {
        KairoRecipeBackendService(dependencies: makeRecipeRunnerDependencies())
    }

    public func makeRecipeRunnerDependencies() -> KairoRecipeRunnerDependencies {
        KairoRecipeRunnerDependencies(
            recipeStore: dependencies.kairoRecipeStore,
            memoryStore: dependencies.memoryStore,
            aiProvider: dependencies.aiProvider,
            actionGate: BuiltInPhoneToolActionGate(toolCatalog: dependencies.toolCatalog),
            appIntegrationSkillCatalog: dependencies.appIntegrationSkillCatalog
        )
    }
}

public struct KairoShareImportBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeShareImportAPI() -> any KairoShareImportAPI {
        KairoShareImportBackendService(
            shareIngestionQueue: dependencies.shareIngestionQueue,
            sharedFilesDirectory: dependencies.sharedFilesDirectory
        )
    }
}

public struct KairoActionBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeActionAPI() -> any KairoActionAPI {
        KairoActionBackendService(actionExecutor: dependencies.actionExecutor)
    }
}

public struct KairoDeletionBackendServiceFactory<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeDeletionAPI() -> any KairoDeletionAPI {
        KairoDeletionBackendService(
            chatHistoryStore: dependencies.chatHistoryStore,
            memoryStore: dependencies.memoryStore,
            credentialStore: dependencies.credentialStore,
            auditLogger: dependencies.auditLogger,
            oauthLoginService: OAuthConnectorLoginServiceFactory().makeLoginService(
                override: nil,
                credentialStore: dependencies.credentialStore,
                oauthConnectorRegistry: dependencies.oauthConnectorRegistry,
                oauthClientConfigurations: dependencies.oauthClientConfigurations,
                oauthCallbackStore: nil
            ),
            localModelSettingsService: dependencies.localModelSettingsService
        )
    }
}

public struct ProductionKairoBackendServiceFactory<Dependencies: KairoBackendDependencies>: KairoBackendServiceMaking {
    private let dependencies: Dependencies
    private let chatFactory: KairoChatBackendServiceFactory<Dependencies>
    private let recipeFactory: KairoRecipeBackendServiceFactory<Dependencies>
    private let shareImportFactory: KairoShareImportBackendServiceFactory<Dependencies>
    private let actionFactory: KairoActionBackendServiceFactory<Dependencies>
    private let deletionFactory: KairoDeletionBackendServiceFactory<Dependencies>
    private let settingsFactory: KairoSettingsBackendServiceFactory<Dependencies>
    private let accessFactory: KairoAccessBackendServiceFactory<Dependencies>

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
        self.chatFactory = KairoChatBackendServiceFactory(dependencies: dependencies)
        self.recipeFactory = KairoRecipeBackendServiceFactory(dependencies: dependencies)
        self.shareImportFactory = KairoShareImportBackendServiceFactory(dependencies: dependencies)
        self.actionFactory = KairoActionBackendServiceFactory(dependencies: dependencies)
        self.deletionFactory = KairoDeletionBackendServiceFactory(dependencies: dependencies)
        self.settingsFactory = KairoSettingsBackendServiceFactory(dependencies: dependencies)
        self.accessFactory = KairoAccessBackendServiceFactory(dependencies: dependencies)
    }

    public func makeChatAPI() -> any KairoChatAPI {
        chatFactory.makeChatAPI()
    }

    public func makeMemoryAPI() -> any KairoMemoryAPI {
        KairoMemoryBackendService(memoryStore: dependencies.memoryStore)
    }

    public func makeRecipeAPI() -> any KairoRecipeAPI {
        recipeFactory.makeRecipeAPI()
    }

    public func makeShareImportAPI() -> any KairoShareImportAPI {
        shareImportFactory.makeShareImportAPI()
    }

    public func makeActionAPI() -> any KairoActionAPI {
        actionFactory.makeActionAPI()
    }

    public func makeDeletionAPI() -> any KairoDeletionAPI {
        deletionFactory.makeDeletionAPI()
    }

    public func makeLocalModelAPI() -> any KairoLocalModelAPI {
        KairoLocalModelBackendService(localModelSettingsService: dependencies.localModelSettingsService)
    }

    public func makeSkillAPI() -> any KairoSkillAPI {
        KairoSkillBackendService(agentSkillManagerService: dependencies.agentSkillManagerService)
    }

    public func makeSettingsAPI() -> any KairoSettingsAPI {
        settingsFactory.makeSettingsAPI()
    }

    public func makeAccessAPI() -> any KairoAccessAPI {
        accessFactory.makeAccessAPI()
    }
}
