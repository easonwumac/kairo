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

        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            candidate(for: skill, normalizedText: normalizedText)
        })
        candidates.append(contentsOf: appIntegrationSkillCatalog.skills.compactMap { skill in
            candidate(for: skill, userText: request.userText, normalizedText: normalizedText)
        })
        let migratedIntegrationKeys = Set(appIntegrationSkillCatalog.skills.map(\.integrationKey))
        candidates.append(contentsOf: integrationRegistry.oauthConnectors.compactMap { integration in
            guard !migratedIntegrationKeys.contains(integration.key) else { return nil }
            return candidate(for: integration, normalizedText: normalizedText)
        })
        for handoffCandidate in visibleHandoffCandidateProvider.candidates(
            userText: request.userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) where !candidates.containsAction(kind: handoffCandidate.action?.kind) {
            candidates.append(handoffCandidate)
        }
        for writeCandidate in writeActionCandidateProvider.candidates(
            userText: request.userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) where !candidates.containsAction(kind: writeCandidate.action?.kind) {
            candidates.append(writeCandidate)
        }

        return AgentToolInvocationPlan(
            candidates: uniqueCandidates(candidates).filter(candidateFilter.allowsCandidate)
        )
    }
}
