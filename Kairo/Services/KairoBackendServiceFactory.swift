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
    var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] { get }
    var agentSkillManagerService: AgentSkillManagerService? { get }
    var localModelSettingsService: LocalModelSettingsService? { get }
    var toolCatalog: any BuiltInPhoneToolCatalogProviding { get }
    var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding { get }
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

public struct ProductionKairoBackendServiceFactory<Dependencies: KairoBackendDependencies>: KairoBackendServiceMaking {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeChatAPI() -> any KairoChatAPI {
        let skillCatalogProvider: AgentSkillCatalogProvider
        if let agentSkillManagerService = dependencies.agentSkillManagerService {
            skillCatalogProvider = .skillManager(agentSkillManagerService)
        } else {
            skillCatalogProvider = .default
        }
        return KairoChatBackendService(agent: AgentCore(
            memoryStore: dependencies.memoryStore,
            aiProvider: dependencies.aiProvider,
            skillCatalogProvider: skillCatalogProvider,
            toolCatalog: dependencies.toolCatalog
        ))
    }

    public func makeMemoryAPI() -> any KairoMemoryAPI {
        KairoMemoryBackendService(memoryStore: dependencies.memoryStore)
    }

    public func makeRecipeAPI() -> any KairoRecipeAPI {
        KairoRecipeBackendService(
            recipeStore: dependencies.kairoRecipeStore,
            memoryStore: dependencies.memoryStore,
            aiProvider: dependencies.aiProvider,
            toolCatalog: dependencies.toolCatalog
        )
    }

    public func makeShareImportAPI() -> any KairoShareImportAPI {
        KairoShareImportBackendService(
            shareIngestionQueue: dependencies.shareIngestionQueue,
            sharedFilesDirectory: dependencies.sharedFilesDirectory
        )
    }

    public func makeActionAPI() -> any KairoActionAPI {
        KairoActionBackendService(actionExecutor: dependencies.actionExecutor)
    }

    public func makeDeletionAPI() -> any KairoDeletionAPI {
        KairoDeletionBackendService(
            chatHistoryStore: dependencies.chatHistoryStore,
            memoryStore: dependencies.memoryStore,
            credentialStore: dependencies.credentialStore,
            auditLogger: dependencies.auditLogger,
            localModelSettingsService: dependencies.localModelSettingsService
        )
    }

    public func makeLocalModelAPI() -> any KairoLocalModelAPI {
        KairoLocalModelBackendService(localModelSettingsService: dependencies.localModelSettingsService)
    }

    public func makeSkillAPI() -> any KairoSkillAPI {
        KairoSkillBackendService(agentSkillManagerService: dependencies.agentSkillManagerService)
    }

    public func makeSettingsAPI() -> any KairoSettingsAPI {
        KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: dependencies.credentialStore),
            oauthLoginCenter: OAuthConnectorLoginCenter(
                credentialStore: dependencies.credentialStore,
                clientConfigurations: dependencies.oauthClientConfigurations
            )
        )
    }

    public func makeAccessAPI() -> any KairoAccessAPI {
        KairoAccessBackendService(
            toolCatalog: dependencies.toolCatalog,
            permissionService: dependencies.permissionService
        )
    }
}
