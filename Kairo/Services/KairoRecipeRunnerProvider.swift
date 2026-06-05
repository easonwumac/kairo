import Foundation

public protocol KairoRecipeRunnerProviding: Sendable {
    func makeStore() async throws -> any KairoRecipeStore
    func makeRunner() async throws -> KairoRecipeRunner
}

public struct LiveKairoRecipeRunnerProvider: KairoRecipeRunnerProviding {
    private let paths: KairoPaths
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(
        paths: KairoPaths = KairoSharedAppStorage.paths(),
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)? = nil,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil
    ) {
        self.paths = paths
        self.toolCatalog = toolCatalog ?? BuiltInPhoneToolCatalog()
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
    }

    public func makeStore() async throws -> any KairoRecipeStore {
        try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
    }

    public func makeRunner() async throws -> KairoRecipeRunner {
        KairoRecipeRunner(
            recipeStore: try await makeStore(),
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
    }
}
