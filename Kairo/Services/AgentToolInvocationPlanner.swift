import Foundation

public struct AgentToolInvocationPlanner: Sendable {
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionMapper: any AppIntegrationActionMapping
    public var appIntegrationActionParser: any AgentToolInvocationActionParsing
    public var visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding
    public var writeActionCandidateProvider: any AgentWriteActionCandidateProviding
    public var candidateMatcher: any AgentToolInvocationCandidateMatching
    public var candidateBuilder: any AgentToolInvocationCandidateBuilding
    public var candidatePipeline: any AgentToolInvocationCandidatePipelining
    public var candidateFilter: any AgentToolCandidateFiltering
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        skillCatalog: AgentSkillCatalog = .default,
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        candidateBuilder: any AgentToolInvocationCandidateBuilding = DefaultAgentToolInvocationCandidateBuilder(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionMapper = appIntegrationActionMapper
        self.appIntegrationActionParser = appIntegrationActionParser
        self.visibleHandoffCandidateProvider = visibleHandoffCandidateProvider
        self.writeActionCandidateProvider = writeActionCandidateProvider
        self.candidateMatcher = candidateMatcher
        self.candidateBuilder = candidateBuilder
        self.candidatePipeline = candidatePipeline
        self.candidateFilter = candidateFilter ?? PhoneToolCandidateFilter(
            actionGate: BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        )
        self.safetyPolicyEngine = safetyPolicyEngine
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

        let candidates = candidatePipeline.candidates(
            for: request,
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionMapper: appIntegrationActionMapper,
            appIntegrationActionParser: appIntegrationActionParser,
            visibleHandoffCandidateProvider: visibleHandoffCandidateProvider,
            writeActionCandidateProvider: writeActionCandidateProvider,
            candidateMatcher: candidateMatcher,
            candidateBuilder: candidateBuilder,
            safetyPolicyEngine: safetyPolicyEngine
        )

        return AgentToolInvocationPlan(
            candidates: candidates.filter(candidateFilter.allowsCandidate)
        )
    }
}
