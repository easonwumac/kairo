import Foundation

public struct AgentToolInvocationPlanner: Sendable {
    public var skillCatalog: AgentSkillCatalog
    public var dependencies: AgentToolInvocationPlannerDependencies

    public init(
        skillCatalog: AgentSkillCatalog = .default,
        dependencies: AgentToolInvocationPlannerDependencies
    ) {
        self.skillCatalog = skillCatalog
        self.dependencies = dependencies
    }

    public init(
        skillCatalog: AgentSkillCatalog = .default,
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
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending = DefaultAgentFallbackActionCandidateAppender(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.init(
            skillCatalog: skillCatalog,
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
                fallbackActionCandidateAppender: fallbackActionCandidateAppender,
                candidatePipeline: candidatePipeline,
                toolCatalog: toolCatalog,
                candidateFilter: candidateFilter,
                safetyPolicyEngine: safetyPolicyEngine
            )
        )
    }

    public func plan(for request: AgentToolInvocationRequest) -> AgentToolInvocationPlan {
        guard request.allowsToolUse else {
            return AgentToolInvocationPlan(
                candidates: [],
                unsupportedMessage: KairoL10n.string("chat.provider.localFallback.toolsUnavailable")
            )
        }

        let normalizedText = normalize(request.matchingText)
        guard !normalizedText.isEmpty else {
            return AgentToolInvocationPlan(candidates: [])
        }

        let candidates = dependencies.candidatePipeline.candidates(
            for: request,
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            integrationRegistry: dependencies.integrationRegistry,
            appIntegrationSkillCatalog: dependencies.appIntegrationSkillCatalog,
            appIntegrationActionMapper: dependencies.appIntegrationActionMapper,
            appIntegrationActionParser: dependencies.appIntegrationActionParser,
            visibleHandoffCandidateProvider: dependencies.visibleHandoffCandidateProvider,
            writeActionCandidateProvider: dependencies.writeActionCandidateProvider,
            candidateMatcher: dependencies.candidateMatcher,
            installedSkillCandidateMapper: dependencies.installedSkillCandidateMapper,
            legacyIntegrationCandidateMapper: dependencies.legacyIntegrationCandidateMapper,
            appIntegrationCandidateMapper: dependencies.appIntegrationCandidateMapper,
            fallbackActionCandidateAppender: dependencies.fallbackActionCandidateAppender,
            safetyPolicyEngine: dependencies.safetyPolicyEngine
        )

        return AgentToolInvocationPlan(
            candidates: candidates.filter(dependencies.candidateFilter.allowsCandidate)
        )
    }
}
