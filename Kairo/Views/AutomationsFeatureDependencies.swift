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
        recipeStore: (any KairoRecipeStore)?,
        memoryStore: (any MemoryStore)?,
        aiProvider: (any AIProvider)?,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)?,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)?
    ) -> AutomationsFeatureDependencies

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: (any MemoryStore)?,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)?,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)?
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
        recipeStore: (any KairoRecipeStore)? = nil,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)? = nil,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil
    ) -> AutomationsFeatureDependencies {
        let runtimeRecipeStore = recipeStore ?? InMemoryKairoRecipeStore()
        let runtimeMemoryStore = memoryStore ?? InMemoryMemoryStore()
        let runtimeToolCatalog = toolCatalog ?? BuiltInPhoneToolCatalog()
        let runtimeAppIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
        return AutomationsFeatureDependencies(
            recipeAPI: KairoRecipeBackendService(
                recipeStore: runtimeRecipeStore,
                memoryStore: memoryStore,
                aiProvider: aiProvider,
                toolCatalog: runtimeToolCatalog,
                appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
            ),
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: runtimeMemoryStore,
                    toolCatalog: runtimeToolCatalog,
                    appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
                ),
                appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
            )
        )
    }

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: (any MemoryStore)? = nil,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)? = nil,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil
    ) -> AutomationsFeatureDependencies {
        let runtimeMemoryStore = memoryStore ?? InMemoryMemoryStore()
        let runtimeToolCatalog = toolCatalog ?? BuiltInPhoneToolCatalog()
        let runtimeAppIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
        return AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutTemplateRegistry: shortcutTemplateRegistry,
            shortcutDemoRecipeRunner: ShortcutDemoRecipeRunner(
                runtime: ShortcutNodeRuntime(
                    memoryStore: runtimeMemoryStore,
                    toolCatalog: runtimeToolCatalog,
                    appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
                ),
                appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
            )
        )
    }

    public func makeDependencies(
        recipeAPI: any KairoRecipeAPI
    ) -> AutomationsFeatureDependencies {
        makeDependencies(
            recipeAPI: recipeAPI,
            memoryStore: nil,
            toolCatalog: nil,
            appIntegrationSkillCatalog: nil
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
