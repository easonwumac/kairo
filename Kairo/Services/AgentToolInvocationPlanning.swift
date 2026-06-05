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

    public init(candidatePlanning: AgentToolCandidatePlanningDependencies) {
        self.init(dependencies: AgentToolInvocationPlannerDependencies(candidatePlanning: candidatePlanning))
    }

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting = DefaultAgentPrimaryToolCandidateCollector(),
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper(),
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending = DefaultAgentFallbackActionCandidateAppender(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine()
    ) {
        self.init(
            candidatePlanning: AgentToolCandidatePlanningDependencies(
                integrationRegistry: integrationRegistry,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog,
                appIntegrationActionMapper: appIntegrationActionMapper,
                appIntegrationActionParser: appIntegrationActionParser,
                visibleHandoffCandidateProvider: visibleHandoffCandidateProvider,
                writeActionCandidateProvider: writeActionCandidateProvider,
                candidateMatcher: candidateMatcher,
                primaryCandidateCollector: primaryCandidateCollector,
                installedSkillCandidateMapper: installedSkillCandidateMapper,
                legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper,
                appIntegrationCandidateMapper: appIntegrationCandidateMapper,
                fallbackActionCandidateAppender: fallbackActionCandidateAppender,
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
