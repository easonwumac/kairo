import Foundation

public struct KairoRecipeRunnerDependencies: Sendable {
    public var recipeStore: any KairoRecipeStore
    public var memoryStore: (any MemoryStore)?
    public var aiProvider: (any AIProvider)?
    public var actionGate: any PhoneToolActionGating

    public init(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        actionGate: any PhoneToolActionGating
    ) {
        self.recipeStore = recipeStore
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
        self.actionGate = actionGate
    }
}
