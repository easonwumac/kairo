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

public protocol AutomationsFeatureDependencyComposing: Sendable {
    func makeDependencies(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)?,
        aiProvider: (any AIProvider)?,
        toolCatalog: any BuiltInPhoneToolCatalogProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    ) -> AutomationsFeatureDependencies

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: any MemoryStore,
        toolCatalog: any BuiltInPhoneToolCatalogProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    ) -> AutomationsFeatureDependencies

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI
    ) -> AutomationsFeatureDependencies

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol
    ) -> AutomationsFeatureDependencies
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
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) -> AutomationsFeatureDependencies {
        let runtimeMemoryStore = memoryStore ?? InMemoryMemoryStore()
        return AutomationsFeatureDependencies(
            recipeAPI: KairoRecipeBackendService(
                recipeStore: recipeStore,
                memoryStore: memoryStore,
                aiProvider: aiProvider,
                toolCatalog: toolCatalog,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            ),
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: runtimeMemoryStore,
                    toolCatalog: toolCatalog,
                    appIntegrationSkillCatalog: appIntegrationSkillCatalog
                ),
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            )
        )
    }

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: any MemoryStore = InMemoryMemoryStore(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: memoryStore,
                    toolCatalog: toolCatalog,
                    appIntegrationSkillCatalog: appIntegrationSkillCatalog
                ),
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            )
        )
    }

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI
    ) -> AutomationsFeatureDependencies {
        makeDependencies(
            recipeAPI: recipeAPI,
            memoryStore: InMemoryMemoryStore(),
            toolCatalog: BuiltInPhoneToolCatalog(),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog()
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

extension AutomationsFeatureDependencyFactory: AutomationsFeatureDependencyComposing {}

public extension KairoEnvironment {
    var automationsFeatureDependencies: AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: backendAPI.recipes,
            shortcutDemoRecipeRunner: shortcutDemoRecipeRunner
        )
    }
}
#endif
