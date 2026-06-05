import Foundation

public protocol AgentToolInvocationPlanning: Sendable {
    func plan(
        for request: AgentToolInvocationRequest,
        skillCatalog: AgentSkillCatalog
    ) -> AgentToolInvocationPlan
}

public struct DefaultAgentToolInvocationPlannerProvider: AgentToolInvocationPlanning {
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var toolCatalog: any BuiltInPhoneToolCatalogProviding
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.toolCatalog = toolCatalog
        self.safetyPolicyEngine = safetyPolicyEngine
    }

    public func plan(
        for request: AgentToolInvocationRequest,
        skillCatalog: AgentSkillCatalog
    ) -> AgentToolInvocationPlan {
        AgentToolInvocationPlanner(
            skillCatalog: skillCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            toolCatalog: toolCatalog,
            safetyPolicyEngine: safetyPolicyEngine
        ).plan(for: request)
    }
}
