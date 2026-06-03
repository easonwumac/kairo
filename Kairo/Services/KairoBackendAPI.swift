import Foundation

public struct KairoBackendAPI: Sendable {
    public let moduleRegistry: KairoBackendModuleRegistry
    public let chat: any KairoChatAPI
    public let memory: any KairoMemoryAPI
    public let recipes: any KairoRecipeAPI
    public let shareImports: any KairoShareImportAPI
    public let deletion: any KairoDeletionAPI
    public let localModels: any KairoLocalModelAPI
    public let skills: any KairoSkillAPI
    public let settings: any KairoSettingsAPI
    public let access: any KairoAccessAPI

    public init(
        moduleRegistry: KairoBackendModuleRegistry = .production,
        chat: any KairoChatAPI,
        memory: any KairoMemoryAPI,
        recipes: any KairoRecipeAPI,
        shareImports: any KairoShareImportAPI,
        deletion: any KairoDeletionAPI,
        localModels: any KairoLocalModelAPI,
        skills: any KairoSkillAPI,
        settings: any KairoSettingsAPI,
        access: any KairoAccessAPI
    ) {
        self.moduleRegistry = moduleRegistry
        self.chat = chat
        self.memory = memory
        self.recipes = recipes
        self.shareImports = shareImports
        self.deletion = deletion
        self.localModels = localModels
        self.skills = skills
        self.settings = settings
        self.access = access
    }
}
