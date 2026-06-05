#if canImport(SwiftUI)
import Foundation

public struct AccessFeatureDependencies {
    public var accessAPI: (any KairoAccessAPI)?
    public var skillManagerService: AgentSkillManagerService?
    public var marketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    public var initialSkillCatalog: AgentSkillCatalog

    public init(
        accessAPI: (any KairoAccessAPI)? = nil,
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples
    ) {
        self.accessAPI = accessAPI
        self.skillManagerService = skillManagerService
        self.marketplaceCatalogService = marketplaceCatalogService
        self.initialSkillCatalog = initialSkillCatalog
    }
}

public struct AccessFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        accessAPI: (any KairoAccessAPI)? = nil,
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples
    ) -> AccessFeatureDependencies {
        AccessFeatureDependencies(
            accessAPI: accessAPI,
            skillManagerService: skillManagerService,
            marketplaceCatalogService: marketplaceCatalogService,
            initialSkillCatalog: initialSkillCatalog
        )
    }
}

public extension KairoEnvironment {
    var accessFeatureDependencies: AccessFeatureDependencies {
        AccessFeatureDependencyFactory().makeDependencies(
            accessAPI: backendAPI.access,
            skillManagerService: agentSkillManagerService,
            marketplaceCatalogService: agentSkillMarketplaceCatalogService
        )
    }
}
#endif
