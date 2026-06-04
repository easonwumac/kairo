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
}

public struct KairoBackendModuleComposer<Dependencies: KairoBackendDependencies>: Sendable {
    private let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    public func makeBackendAPI(moduleRegistry: KairoBackendModuleRegistry = .production) -> KairoBackendAPI {
        let skillCatalogProvider: AgentSkillCatalogProvider
        if let agentSkillManagerService = dependencies.agentSkillManagerService {
            skillCatalogProvider = .skillManager(agentSkillManagerService)
        } else {
            skillCatalogProvider = .default
        }
        let agent = AgentCore(
            memoryStore: dependencies.memoryStore,
            aiProvider: dependencies.aiProvider,
            skillCatalogProvider: skillCatalogProvider
        )

        return KairoBackendAPI(
            moduleRegistry: moduleRegistry,
            chat: KairoChatBackendService(agent: agent),
            memory: KairoMemoryBackendService(memoryStore: dependencies.memoryStore),
            recipes: KairoRecipeBackendService(
                recipeStore: dependencies.kairoRecipeStore,
                memoryStore: dependencies.memoryStore,
                aiProvider: dependencies.aiProvider
            ),
            shareImports: KairoShareImportBackendService(
                shareIngestionQueue: dependencies.shareIngestionQueue,
                sharedFilesDirectory: dependencies.sharedFilesDirectory
            ),
            actions: KairoActionBackendService(
                actionExecutor: dependencies.actionExecutor
            ),
            deletion: KairoDeletionBackendService(
                chatHistoryStore: dependencies.chatHistoryStore,
                memoryStore: dependencies.memoryStore,
                credentialStore: dependencies.credentialStore,
                auditLogger: dependencies.auditLogger,
                localModelSettingsService: dependencies.localModelSettingsService
            ),
            localModels: KairoLocalModelBackendService(
                localModelSettingsService: dependencies.localModelSettingsService
            ),
            skills: KairoSkillBackendService(
                agentSkillManagerService: dependencies.agentSkillManagerService
            ),
            settings: KairoSettingsBackendService(
                openAISettingsService: OpenAISettingsService(credentialStore: dependencies.credentialStore),
                oauthLoginCenter: OAuthConnectorLoginCenter(
                    credentialStore: dependencies.credentialStore,
                    clientConfigurations: dependencies.oauthClientConfigurations
                )
            ),
            access: KairoAccessBackendService(
                permissionService: dependencies.permissionService
            )
        )
    }
}
