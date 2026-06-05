#if canImport(SwiftUI)
import Foundation

public struct AutomationsFeatureDependencies {
    public var recipeAPI: any KairoRecipeAPI
    public var shortcutTemplateRegistry: ShortcutTemplateRegistry
    public var shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol

    public init(
        recipeAPI: any KairoRecipeAPI,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = .default,
        shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol
    ) {
        self.recipeAPI = recipeAPI
        self.shortcutTemplateRegistry = shortcutTemplateRegistry
        self.shortcutDemoRecipeRunner = shortcutDemoRecipeRunner
    }

    public init(
        recipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = .default,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) {
        let runtimeMemoryStore = memoryStore ?? InMemoryMemoryStore()
        self.init(
            recipeAPI: KairoRecipeBackendService(
                recipeStore: recipeStore,
                memoryStore: memoryStore,
                aiProvider: aiProvider,
                toolCatalog: toolCatalog
            ),
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: runtimeMemoryStore,
                    toolCatalog: toolCatalog
                )
            )
        )
    }

    public init(
        recipeAPI: any KairoRecipeAPI,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = .default,
        memoryStore: any MemoryStore = InMemoryMemoryStore(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) {
        self.init(
            recipeAPI: recipeAPI,
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: memoryStore,
                    toolCatalog: toolCatalog
                )
            )
        )
    }
}

public extension KairoEnvironment {
    var automationsFeatureDependencies: AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: backendAPI.recipes,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: memoryStore,
                    toolCatalog: toolCatalog
                )
            )
        )
    }
}
#endif
