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
