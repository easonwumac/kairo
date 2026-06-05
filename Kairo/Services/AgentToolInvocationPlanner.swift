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
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting = DefaultAgentPrimaryToolCandidateCollector(),
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
                primaryCandidateCollector: primaryCandidateCollector,
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

        let candidatePlanning = dependencies.candidatePlanning
        let candidates = candidatePlanning.candidatePipeline.candidates(in: AgentToolInvocationCandidatePipelineContext(
            request: request,
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            integrationRegistry: candidatePlanning.integrationRegistry,
            appIntegrationSkillCatalog: candidatePlanning.appIntegrationSkillCatalog,
            appIntegrationActionMapper: candidatePlanning.appIntegrationActionMapper,
            appIntegrationActionParser: candidatePlanning.appIntegrationActionParser,
            visibleHandoffCandidateProvider: candidatePlanning.visibleHandoffCandidateProvider,
            writeActionCandidateProvider: candidatePlanning.writeActionCandidateProvider,
            candidateMatcher: candidatePlanning.candidateMatcher,
            primaryCandidateCollector: candidatePlanning.primaryCandidateCollector,
            installedSkillCandidateMapper: candidatePlanning.installedSkillCandidateMapper,
            legacyIntegrationCandidateMapper: candidatePlanning.legacyIntegrationCandidateMapper,
            appIntegrationCandidateMapper: candidatePlanning.appIntegrationCandidateMapper,
            fallbackActionCandidateAppender: candidatePlanning.fallbackActionCandidateAppender,
            safetyPolicyEngine: candidatePlanning.safetyPolicyEngine
        ))

        return AgentToolInvocationPlan(
            candidates: candidates.filter(candidatePlanning.candidateFilter.allowsCandidate)
        )
    }
}
