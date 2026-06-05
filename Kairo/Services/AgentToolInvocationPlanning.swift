import Foundation

public protocol AgentToolInvocationPlanning: Sendable {
    func plan(
        for request: AgentToolInvocationRequest,
        skillCatalog: AgentSkillCatalog
    ) -> AgentToolInvocationPlan
}

public struct DefaultAgentToolInvocationPlannerProvider: AgentToolInvocationPlanning {
    public var dependencies: AgentToolInvocationPlannerDependencies

    public init(dependencies: AgentToolInvocationPlannerDependencies) {
        self.dependencies = dependencies
    }

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.init(
            dependencies: AgentToolInvocationPlannerDependencies(
                integrationRegistry: integrationRegistry,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog,
                appIntegrationActionMapper: appIntegrationActionMapper,
                appIntegrationActionParser: appIntegrationActionParser,
                visibleHandoffCandidateProvider: visibleHandoffCandidateProvider,
                writeActionCandidateProvider: writeActionCandidateProvider,
                candidateMatcher: candidateMatcher,
                installedSkillCandidateMapper: installedSkillCandidateMapper,
                legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper,
                appIntegrationCandidateMapper: appIntegrationCandidateMapper,
                candidatePipeline: candidatePipeline,
                toolCatalog: toolCatalog,
                safetyPolicyEngine: safetyPolicyEngine
            )
        )
    }

    public func plan(
        for request: AgentToolInvocationRequest,
        skillCatalog: AgentSkillCatalog
    ) -> AgentToolInvocationPlan {
        AgentToolInvocationPlanner(
            skillCatalog: skillCatalog,
            dependencies: dependencies
        ).plan(for: request)
    }
}
