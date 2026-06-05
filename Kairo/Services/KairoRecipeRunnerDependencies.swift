import Foundation

public struct KairoRecipeRunnerDependencies: Sendable {
    public var recipeStore: any KairoRecipeStore
    public var memoryStore: (any MemoryStore)?
    public var aiProvider: (any AIProvider)?
    public var actionGate: any PhoneToolActionGating
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionDrafter: any AppIntegrationActionDrafting
    public var integrationActionDrafter: any KairoRecipeIntegrationActionDrafting
    public var inputResolver: any KairoRecipeStepInputResolving

    public init(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        actionGate: any PhoneToolActionGating,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionDrafter: any AppIntegrationActionDrafting = DefaultAppIntegrationActionDrafter(),
        integrationActionDrafter: (any KairoRecipeIntegrationActionDrafting)? = nil,
        inputResolver: any KairoRecipeStepInputResolving = DefaultKairoRecipeStepInputResolver()
    ) {
        self.recipeStore = recipeStore
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
        self.actionGate = actionGate
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionDrafter = appIntegrationActionDrafter
        self.integrationActionDrafter = integrationActionDrafter ?? CatalogBackedKairoRecipeIntegrationActionDrafter(
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionDrafter: appIntegrationActionDrafter
        )
        self.inputResolver = inputResolver
    }
}
