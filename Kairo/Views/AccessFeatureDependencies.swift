#if canImport(SwiftUI)
import Foundation

public struct AccessFeatureDependencies {
    public var skillManagerService: AgentSkillManagerService?
    public var marketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    public var initialSkillCatalog: AgentSkillCatalog

    public init(
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples
    ) {
        self.skillManagerService = skillManagerService
        self.marketplaceCatalogService = marketplaceCatalogService
        self.initialSkillCatalog = initialSkillCatalog
    }
}

public extension KairoEnvironment {
    var accessFeatureDependencies: AccessFeatureDependencies {
        AccessFeatureDependencies(
            skillManagerService: agentSkillManagerService,
            marketplaceCatalogService: agentSkillMarketplaceCatalogService
        )
    }
}
#endif
