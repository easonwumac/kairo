#if canImport(SwiftUI)
import Foundation

public struct AccessFeatureDependencies {
    public var accessAPI: (any KairoAccessAPI)?
    public var skillManagerService: AgentSkillManagerService?
    public var marketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    public var initialSkillCatalog: AgentSkillCatalog
    public var capabilityRegistry: any CapabilityRegistryProviding

    public init(
        accessAPI: (any KairoAccessAPI)? = nil,
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples,
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry()
    ) {
        self.accessAPI = accessAPI
        self.skillManagerService = skillManagerService
        self.marketplaceCatalogService = marketplaceCatalogService
        self.initialSkillCatalog = initialSkillCatalog
        self.capabilityRegistry = capabilityRegistry
    }
}

public struct AccessFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        accessAPI: (any KairoAccessAPI)? = nil,
        skillManagerService: AgentSkillManagerService? = nil,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        initialSkillCatalog: AgentSkillCatalog = .defaultWithMarketplaceSamples,
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry()
    ) -> AccessFeatureDependencies {
        AccessFeatureDependencies(
            accessAPI: accessAPI,
            skillManagerService: skillManagerService,
            marketplaceCatalogService: marketplaceCatalogService,
            initialSkillCatalog: initialSkillCatalog,
            capabilityRegistry: capabilityRegistry
        )
    }
}

public extension KairoEnvironment {
    var accessFeatureDependencies: AccessFeatureDependencies {
        AccessFeatureDependencyFactory().makeDependencies(
            accessAPI: backendAPI.access,
            skillManagerService: agentSkillManagerService,
            marketplaceCatalogService: agentSkillMarketplaceCatalogService,
            capabilityRegistry: capabilityRegistry
        )
    }
}
#endif
