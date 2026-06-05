import Foundation

public protocol AgentCapabilityPromptContextProviding: Sendable {
    func buildToolContext(skillCatalog: AgentSkillCatalog) -> String
}

public struct DefaultAgentCapabilityPromptContextProvider: AgentCapabilityPromptContextProviding {
    public var capabilityRegistry: CapabilityRegistry
    public var toolCatalog: any BuiltInPhoneToolCatalogProviding
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var backgroundTaskPolicy: BackgroundTaskPolicy

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        backgroundTaskPolicy: BackgroundTaskPolicy = BackgroundTaskPolicy()
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.toolCatalog = toolCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.backgroundTaskPolicy = backgroundTaskPolicy
    }

    public func buildToolContext(skillCatalog: AgentSkillCatalog) -> String {
        CapabilityPromptContextBuilder(
            capabilityRegistry: capabilityRegistry,
            toolCatalog: toolCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            backgroundTaskPolicy: backgroundTaskPolicy,
            skillCatalog: skillCatalog
        ).build()
    }
}
