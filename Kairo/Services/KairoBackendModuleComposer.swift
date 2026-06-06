import Foundation

public struct KairoBackendModuleComposer: Sendable {
    private let serviceFactory: any KairoBackendServiceMaking

    public init(serviceFactory: any KairoBackendServiceMaking) {
        self.serviceFactory = serviceFactory
    }

    public init<Dependencies: KairoBackendDependencies>(dependencies: Dependencies) {
        self.serviceFactory = ProductionKairoBackendServiceFactory(dependencies: dependencies)
    }

    public func makeBackendAPI(moduleRegistry: KairoBackendModuleRegistry = .production) -> KairoBackendAPI {
        return KairoBackendAPI(
            moduleRegistry: moduleRegistry,
            chat: serviceFactory.makeChatAPI(),
            memory: serviceFactory.makeMemoryAPI(),
            knowledgeAssets: serviceFactory.makeKnowledgeAssetAPI(),
            recipes: serviceFactory.makeRecipeAPI(),
            shareImports: serviceFactory.makeShareImportAPI(),
            actionInbox: serviceFactory.makeActionInboxAPI(),
            actions: serviceFactory.makeActionAPI(),
            deletion: serviceFactory.makeDeletionAPI(),
            localModels: serviceFactory.makeLocalModelAPI(),
            skills: serviceFactory.makeSkillAPI(),
            settings: serviceFactory.makeSettingsAPI(),
            access: serviceFactory.makeAccessAPI()
        )
    }
}
