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
}

public struct AutomationsFeatureDependencyFactory: Sendable {
    public var shortcutTemplateRegistry: ShortcutTemplateRegistry

    public init(shortcutTemplateRegistry: ShortcutTemplateRegistry = .default) {
        self.shortcutTemplateRegistry = shortcutTemplateRegistry
    }

    public func makeDependencies(
        recipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) -> AutomationsFeatureDependencies {
        let runtimeMemoryStore = memoryStore ?? InMemoryMemoryStore()
        return AutomationsFeatureDependencies(
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

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: any MemoryStore = InMemoryMemoryStore(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
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

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol
    ) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: shortcutDemoRecipeRunner
        )
    }
}

public extension KairoEnvironment {
    var automationsFeatureDependencies: AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: backendAPI.recipes,
            shortcutDemoRecipeRunner: shortcutDemoRecipeRunner
        )
    }
}
#endif
