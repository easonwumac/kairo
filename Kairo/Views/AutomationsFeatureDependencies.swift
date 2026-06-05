#if canImport(SwiftUI)
import Foundation

public struct AutomationsFeatureDependencies {
    public var recipeAPI: any KairoRecipeAPI
    public var shortcutTemplateRegistry: ShortcutTemplateRegistry

    public init(
        recipeAPI: any KairoRecipeAPI = KairoRecipeBackendService(recipeStore: InMemoryKairoRecipeStore()),
        shortcutTemplateRegistry: ShortcutTemplateRegistry = .default
    ) {
        self.recipeAPI = recipeAPI
        self.shortcutTemplateRegistry = shortcutTemplateRegistry
    }
}

public extension KairoEnvironment {
    var automationsFeatureDependencies: AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(recipeAPI: backendAPI.recipes)
    }
}
#endif
