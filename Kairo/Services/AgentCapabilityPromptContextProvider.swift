import Foundation

public protocol AgentCapabilityPromptContextProviding: Sendable {
    func buildToolContext(skillCatalog: AgentSkillCatalog) -> String
}

public struct DefaultAgentCapabilityPromptContextProvider: AgentCapabilityPromptContextProviding {
    public var capabilityRegistry: any CapabilityRegistryProviding
    public var toolCatalog: any BuiltInPhoneToolCatalogProviding
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var backgroundTaskPolicy: BackgroundTaskPolicy
    public var policyProvider: any CapabilityToolPolicyProviding

    public init(
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        backgroundTaskPolicy: BackgroundTaskPolicy = BackgroundTaskPolicy(),
        policyProvider: any CapabilityToolPolicyProviding = DefaultCapabilityToolPolicyProvider()
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.toolCatalog = toolCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.backgroundTaskPolicy = backgroundTaskPolicy
        self.policyProvider = policyProvider
    }

    public func buildToolContext(skillCatalog: AgentSkillCatalog) -> String {
        CapabilityPromptContextBuilder(
            capabilityRegistry: capabilityRegistry,
            toolCatalog: toolCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            backgroundTaskPolicy: backgroundTaskPolicy,
            skillCatalog: skillCatalog,
            policyProvider: policyProvider
        ).build()
    }
}
