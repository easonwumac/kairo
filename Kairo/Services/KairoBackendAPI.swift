import Foundation

public struct KairoBackendAPI: Sendable {
    public let moduleRegistry: KairoBackendModuleRegistry
    public let chat: any KairoChatAPI
    public let memory: any KairoMemoryAPI
    public let knowledgeAssets: any KairoKnowledgeAssetAPI
    public let recipes: any KairoRecipeAPI
    public let shareImports: any KairoShareImportAPI
    public let actionInbox: any KairoActionInboxAPI
    public let actions: any KairoActionAPI
    public let deletion: any KairoDeletionAPI
    public let localModels: any KairoLocalModelAPI
    public let skills: any KairoSkillAPI
    public let settings: any KairoSettingsAPI
    public let access: any KairoAccessAPI

    public init(
        moduleRegistry: KairoBackendModuleRegistry = .production,
        chat: any KairoChatAPI,
        memory: any KairoMemoryAPI,
        knowledgeAssets: any KairoKnowledgeAssetAPI,
        recipes: any KairoRecipeAPI,
        shareImports: any KairoShareImportAPI,
        actionInbox: any KairoActionInboxAPI,
        actions: any KairoActionAPI,
        deletion: any KairoDeletionAPI,
        localModels: any KairoLocalModelAPI,
        skills: any KairoSkillAPI,
        settings: any KairoSettingsAPI,
        access: any KairoAccessAPI
    ) {
        self.moduleRegistry = moduleRegistry
        self.chat = chat
        self.memory = memory
        self.knowledgeAssets = knowledgeAssets
        self.recipes = recipes
        self.shareImports = shareImports
        self.actionInbox = actionInbox
        self.actions = actions
        self.deletion = deletion
        self.localModels = localModels
        self.skills = skills
        self.settings = settings
        self.access = access
    }
}
