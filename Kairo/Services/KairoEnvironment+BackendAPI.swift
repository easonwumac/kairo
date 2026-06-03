import Foundation

public extension KairoEnvironment {
    var backendAPI: KairoBackendAPI {
        let skillCatalogProvider: AgentSkillCatalogProvider
        if let agentSkillManagerService {
            skillCatalogProvider = .skillManager(agentSkillManagerService)
        } else {
            skillCatalogProvider = .default
        }
        let agent = AgentCore(
            memoryStore: memoryStore,
            aiProvider: aiProvider,
            skillCatalogProvider: skillCatalogProvider
        )
        return KairoBackendAPI(
            chat: KairoChatBackendService(agent: agent),
            memory: KairoMemoryBackendService(memoryStore: memoryStore),
            recipes: KairoRecipeBackendService(
                recipeStore: kairoRecipeStore,
                memoryStore: memoryStore,
                aiProvider: aiProvider
            ),
            shareImports: KairoShareImportBackendService(
                shareIngestionQueue: shareIngestionQueue
            ),
            deletion: KairoDeletionBackendService(
                chatHistoryStore: chatHistoryStore,
                memoryStore: memoryStore,
                credentialStore: credentialStore,
                auditLogger: auditLogger,
                localModelSettingsService: localModelSettingsService
            ),
            localModels: KairoLocalModelBackendService(
                localModelSettingsService: localModelSettingsService
            ),
            skills: KairoSkillBackendService(
                agentSkillManagerService: agentSkillManagerService
            ),
            settings: KairoSettingsBackendService(
                openAISettingsService: OpenAISettingsService(credentialStore: credentialStore),
                oauthLoginCenter: OAuthConnectorLoginCenter(credentialStore: credentialStore)
            ),
            access: KairoAccessBackendService(
                permissionService: permissionService
            )
        )
    }
}
