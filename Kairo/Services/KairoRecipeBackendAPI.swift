import Foundation

public protocol KairoRecipeAPI: Sendable {
    func listRecipes() async throws -> [KairoRecipe]
    func recipe(id: String) async throws -> KairoRecipe?
    func save(_ recipe: KairoRecipe) async throws
    func delete(id: String) async throws
    func setEnabled(_ enabled: Bool, id: String) async throws
    func seedSampleRecipes() async throws -> [KairoRecipe]
    func run(_ request: KairoRecipeRunRequest) async throws -> KairoRecipeRunResult
}

public struct KairoRecipeBackendService: KairoRecipeAPI {
    private let recipeStore: any KairoRecipeStore
    private let runner: KairoRecipeRunner

    public init(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil
    ) {
        self.recipeStore = recipeStore
        self.runner = KairoRecipeRunner(
            recipeStore: recipeStore,
            memoryStore: memoryStore,
            aiProvider: aiProvider
        )
    }

    public func listRecipes() async throws -> [KairoRecipe] {
        try await recipeStore.listRecipes()
    }

    public func recipe(id: String) async throws -> KairoRecipe? {
        try await recipeStore.recipe(id: id)
    }

    public func save(_ recipe: KairoRecipe) async throws {
        try await recipeStore.save(recipe)
    }

    public func delete(id: String) async throws {
        try await recipeStore.delete(id: id)
    }

    public func setEnabled(_ enabled: Bool, id: String) async throws {
        try await recipeStore.setEnabled(enabled, id: id)
    }

    public func seedSampleRecipes() async throws -> [KairoRecipe] {
        for recipe in KairoRecipeTemplateFactory.sampleCatalog().recipes {
            try await recipeStore.save(recipe)
        }
        return try await recipeStore.listRecipes()
    }

    public func run(_ request: KairoRecipeRunRequest) async throws -> KairoRecipeRunResult {
        try await runner.run(request)
    }
}
